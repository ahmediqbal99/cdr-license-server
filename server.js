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

/// 🔥 DATABASE (can move to MongoDB later)
let licenses = {};

/// 🔑 GENERATE LICENSE (ADMIN)
app.get('/generate', async (req, res) => {

  const adminKey = req.headers['admin-key'];

  if (adminKey !== ADMIN_KEY) {
    return res.status(403).json({ error: "Unauthorized" });
  }

  const key = uuidv4().replace(/-/g,'').substring(0,12).toUpperCase();

  const expiryDate = new Date();
  expiryDate.setDate(expiryDate.getDate() + 30);

  await db.collection('licenses').doc(key).set({
    key,
    device_id: null,
    status: "active",
    expiry: expiryDate,
    createdAt: new Date()
  });

  res.json({ key, expiry: expiryDate });
});


/// 🔐 ACTIVATE
app.post('/activate', async (req, res) => {

  const { key, device_id } = req.body;

  const doc = await db.collection('licenses').doc(key).get();

  if (!doc.exists) {
    return res.json({ status: "invalid" });
  }

  const data = doc.data();

  if (data.status === "revoked") return res.json({ status: "revoked" });

  if (new Date() > data.expiry.toDate()) {
    return res.json({ status: "expired" });
  }

  if (data.device_id === null) {
    await doc.ref.update({ device_id });
    return res.json({ status: "activated" });
  }

  if (data.device_id === device_id) {
    return res.json({ status: "valid" });
  }

  return res.json({ status: "used_on_other_device" });
});


/// 🔍 CHECK LICENSE
app.get('/licenses', async (req, res) => {

  const adminKey = req.headers['admin-key'];

  if (adminKey !== ADMIN_KEY) {
    return res.status(403).json({ error: "Unauthorized" });
  }

  const snapshot = await db.collection('licenses').get();

  const data = snapshot.docs.map(doc => doc.data());

  res.json(data);
});


/// ❌ REVOKE LICENSE (ADMIN)
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


/// 📋 LIST ALL LICENSES (ADMIN)
app.get('/licenses', (req, res) => {

  const adminKey = req.headers['admin-key'];

  if (adminKey !== ADMIN_KEY) {
    return res.status(403).json({ error: "Unauthorized" });
  }

  res.json(licenses);
});
app.get('/test', async (req, res) => {

  await db.collection('test').doc('check').set({
    message: "Firebase connected 🚀"
  });

  res.send("OK");
});

/// 🚀 SERVER START
const PORT = process.env.PORT || 4000;

app.listen(PORT, () => {
  console.log("🚀 License server running on port " + PORT);
});