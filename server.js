const admin = require('firebase-admin');

const serviceAccount = JSON.parse(process.env.FIREBASE_KEY);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(cors());
app.use(bodyParser.json());
app.use(express.static('public'));

const ADMIN_KEY = process.env.ADMIN_KEY;

/// 🔑 GENERATE LICENSE
app.get('/generate', async (req, res) => {

  const adminKey = req.headers['admin-key'];
  const type = req.query.type || "30";
  // Defaults to the product every key predates this field was for, so this stays a no-op
  // for any caller (like the existing admin dashboard, until it's updated) that doesn't
  // pass one yet.
  const product = req.query.product || "cdr_analyzer";

  if (adminKey !== ADMIN_KEY) {
    return res.status(403).json({ error: "Unauthorized" });
  }

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
});


/// 🔐 ACTIVATE
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

  const adminKey = req.headers['admin-key'];

  if (adminKey !== ADMIN_KEY) {
    return res.status(403).json({ error: "Unauthorized" });
  }

  const snapshot = await db.collection('licenses').get();

  const data = snapshot.docs.map(doc => doc.data());

  res.json(data);
});


/// 📝 SET NAME (who this device/key belongs to - admin fills this in manually once they know)
app.post('/set-name', async (req, res) => {

  const adminKey = req.headers['admin-key'];

  if (adminKey !== ADMIN_KEY) {
    return res.status(403).json({ error: "Unauthorized" });
  }

  const { key, name } = req.body;

  await db.collection('licenses').doc(key).update({
    name: name || ""
  });

  res.json({ success: true });
});


/// ❌ REVOKE
app.post('/revoke', async (req, res) => {

  const adminKey = req.headers['admin-key'];

  if (adminKey !== ADMIN_KEY) {
    return res.status(403).json({ error: "Unauthorized" });
  }

  const { key } = req.body;

  await db.collection('licenses').doc(key).update({
    status: "revoked"
  });

  res.json({ success: true });
});


/// 🗑️ DELETE (permanently removes the license record, unlike revoke which just flags it)
app.post('/delete', async (req, res) => {

  const adminKey = req.headers['admin-key'];

  if (adminKey !== ADMIN_KEY) {
    return res.status(403).json({ error: "Unauthorized" });
  }

  const { key } = req.body;

  await db.collection('licenses').doc(key).delete();

  res.json({ success: true });
});


/// 🧪 TEST
app.get('/test', async (req, res) => {

  await db.collection('test').doc('check').set({
    message: "Firebase connected 🚀"
  });

  res.send("OK");
});


/// 🚀 START SERVER
const PORT = process.env.PORT || 4000;

app.listen(PORT, () => {
  console.log("🚀 License server running on port " + PORT);
});