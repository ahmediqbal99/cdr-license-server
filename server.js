const admin = require('firebase-admin');

const serviceAccount = JSON.parse(process.env.FIREBASE_KEY);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(cors());
app.use(bodyParser.json());
app.use(express.static('public'));

// This used to double as the secret that admin.html put directly into client-side JS -
// anyone who viewed the page source got both the login password AND the API key that
// bypasses it entirely. It's now purely a server-side secret: the password an admin types
// at /login, checked here and never sent back to the browser. See requireSession() below
// for what admin.html actually holds after logging in (a short-lived opaque token, not
// this value).
const ADMIN_PASSWORD = process.env.ADMIN_KEY;

// 🔐 SESSIONS - in-memory on purpose. This is a small single-instance admin tool, not
// something that needs Redis; a Render restart just means logging in again, which is fine.
const SESSION_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours
const sessions = new Map(); // token -> expiry timestamp (ms)

function createSession() {
  const token = crypto.randomBytes(24).toString('hex');
  sessions.set(token, Date.now() + SESSION_TTL_MS);
  return token;
}

function requireSession(req, res) {
  const token = req.headers['session-token'];
  const expiry = token && sessions.get(token);

  if (!expiry || Date.now() > expiry) {
    if (token) sessions.delete(token); // expired - stop tracking it
    res.status(403).json({ error: "Unauthorized" });
    return false;
  }

  return true;
}

// Idle session cleanup, so `sessions` doesn't grow unbounded across a long server lifetime.
setInterval(() => {
  const now = Date.now();
  for (const [token, expiry] of sessions) {
    if (now > expiry) sessions.delete(token);
  }
}, 60 * 60 * 1000);

// 🛡️ SAFETY NET: an unhandled promise rejection (e.g. .update() on a license doc that
// doesn't exist) terminates the whole Node process on modern Node by default - confirmed
// the hard way, a single bad /renew request on a stale key took the entire service down
// for every user until Render restarted it. Every route below is also wrapped in its own
// try/catch now, but this is the backstop for anything that still slips through.
process.on('unhandledRejection', (err) => {
  console.error('UNHANDLED REJECTION (server stayed up):', err);
});


/// 🔐 LOGIN - the only endpoint that ever sees ADMIN_PASSWORD. Success gets a session
/// token; the password itself never goes anywhere else, including back to the browser.
app.post('/login', (req, res) => {
  const { password } = req.body;

  if (password !== ADMIN_PASSWORD) {
    return res.status(401).json({ error: "wrong_password" });
  }

  res.json({ token: createSession() });
});


/// 🔑 GENERATE LICENSE
app.get('/generate', async (req, res) => {
  try {

    if (!requireSession(req, res)) return;

    const type = req.query.type || "30";
    // Defaults to the product every key predates this field was for, so this stays a no-op
    // for any caller (like the existing admin dashboard, until it's updated) that doesn't
    // pass one yet.
    const product = req.query.product || "cdr_analyzer";

    const key = uuidv4().replace(/-/g,'').substring(0,12).toUpperCase();

    let expiryDate = null;

    if (type === "30") {
      expiryDate = new Date();
      expiryDate.setDate(expiryDate.getDate() + 30);
    }

    if (type === "90") {
      expiryDate = new Date();
      expiryDate.setDate(expiryDate.getDate() + 90);
    }

    if (type === "lifetime") {
      expiryDate = null; // 🔥 IMPORTANT
    }

    await db.collection('licenses').doc(key).set({
      key,
      device_id: null,
      status: "active",
      expiry: expiryDate,
      type: type,
      product: product,
      name: "", // 📝 filled in later by the admin from the dashboard, once they know who holds the key
      createdAt: new Date()
    });

    res.json({ key, expiry: expiryDate, type, product });

  } catch (e) {
    console.log("GENERATE ERROR:", e);
    res.status(500).json({ error: "server_error" });
  }
});


/// 🔐 ACTIVATE (called by the CDR Analyzer / Extractor apps themselves, not the admin
/// dashboard - unauthenticated by design, gated only by needing a real license key)
app.post('/activate', async (req, res) => {
  try {

    const { key, device_id, product } = req.body;
    // Same default as /generate: a caller that doesn't send `product` (the existing,
    // unmodified CDR Analyzer app) is assumed to mean the product every key predates this
    // field was already for - so already-issued keys keep working with zero client changes.
    const requestedProduct = product || "cdr_analyzer";

    const doc = await db.collection('licenses').doc(key).get();

    if (!doc.exists) return res.json({ status: "invalid" });

    const data = doc.data();

    if (data.status === "revoked")
      return res.json({ status: "revoked" });

    /// 🔀 PRODUCT CHECK - a CDR Analyzer key must not unlock the Extractor and vice versa.
    /// Checked before the device-binding step below, so a wrong-product attempt never
    /// consumes the key's one-device binding.
    const keyProduct = data.product || "cdr_analyzer";
    if (keyProduct !== requestedProduct)
      return res.json({ status: "wrong_product" });

    /// ✅ FIXED expiry handling
    if (data.expiry) {
      let expiryDate;

      if (data.expiry.toDate) {
        expiryDate = data.expiry.toDate();
      } else {
        expiryDate = new Date(data.expiry);
      }

      if (new Date() > expiryDate) {
        return res.json({ status: "expired" });
      }
    }

    if (data.device_id === null) {
      await doc.ref.update({ device_id });
      return res.json({ status: "activated" });
    }

    if (data.device_id === device_id)
      return res.json({ status: "valid" });

    return res.json({ status: "used_on_other_device" });

  } catch (e) {
    console.log("ACTIVATE ERROR:", e);
    return res.json({ status: "server_error" });
  }
});


/// 📋 LIST LICENSES
app.get('/licenses', async (req, res) => {
  try {

    if (!requireSession(req, res)) return;

    const snapshot = await db.collection('licenses').get();

    const data = snapshot.docs.map(doc => doc.data());

    res.json(data);

  } catch (e) {
    console.log("LICENSES ERROR:", e);
    res.status(500).json({ error: "server_error" });
  }
});


/// 📝 SET NAME (who this device/key belongs to - admin fills this in manually once they know)
app.post('/set-name', async (req, res) => {
  try {

    if (!requireSession(req, res)) return;

    const { key, name } = req.body;

    const doc = await db.collection('licenses').doc(key).get();
    if (!doc.exists) return res.status(404).json({ error: "not_found" });

    await doc.ref.update({ name: name || "" });

    res.json({ success: true });

  } catch (e) {
    console.log("SET-NAME ERROR:", e);
    res.status(500).json({ error: "server_error" });
  }
});


/// ❌ REVOKE
app.post('/revoke', async (req, res) => {
  try {

    if (!requireSession(req, res)) return;

    const { key } = req.body;

    const doc = await db.collection('licenses').doc(key).get();
    if (!doc.exists) return res.status(404).json({ error: "not_found" });

    await doc.ref.update({ status: "revoked" });

    res.json({ success: true });

  } catch (e) {
    console.log("REVOKE ERROR:", e);
    res.status(500).json({ error: "server_error" });
  }
});


/// 🔁 RENEW (pushes expiry forward from today; does not touch status, so a revoked key
/// stays revoked until explicitly un-revoked - renew alone shouldn't undo a ban)
app.post('/renew', async (req, res) => {
  try {

    if (!requireSession(req, res)) return;

    const { key, type } = req.body;

    const doc = await db.collection('licenses').doc(key).get();
    if (!doc.exists) return res.status(404).json({ error: "not_found" });

    let expiryDate = null;

    if (type === "30") {
      expiryDate = new Date();
      expiryDate.setDate(expiryDate.getDate() + 30);
    }

    if (type === "90") {
      expiryDate = new Date();
      expiryDate.setDate(expiryDate.getDate() + 90);
    }

    if (type === "lifetime") {
      expiryDate = null; // 🔥 IMPORTANT
    }

    await doc.ref.update({ expiry: expiryDate, type: type });

    res.json({ success: true, expiry: expiryDate });

  } catch (e) {
    console.log("RENEW ERROR:", e);
    res.status(500).json({ error: "server_error" });
  }
});


/// 🗑️ DELETE (permanently removes the license record, unlike revoke which just flags it)
app.post('/delete', async (req, res) => {
  try {

    if (!requireSession(req, res)) return;

    const { key } = req.body;

    await db.collection('licenses').doc(key).delete();

    res.json({ success: true });

  } catch (e) {
    console.log("DELETE ERROR:", e);
    res.status(500).json({ error: "server_error" });
  }
});


/// 🧪 TEST
app.get('/test', async (req, res) => {
  try {

    await db.collection('test').doc('check').set({
      message: "Firebase connected 🚀"
    });

    res.send("OK");

  } catch (e) {
    console.log("TEST ERROR:", e);
    res.status(500).json({ error: "server_error" });
  }
});


/// 🚀 START SERVER
const PORT = process.env.PORT || 4000;

app.listen(PORT, () => {
  console.log("🚀 License server running on port " + PORT);
});
