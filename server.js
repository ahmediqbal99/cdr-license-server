<<<<<<< HEAD
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(cors());
app.use(bodyParser.json());

/// 🔥 FAKE DATABASE (later can move to MongoDB)
let licenses = {
  "ABC123-XYZ789": {
    device_id: null,
    status: "active"
  }
};

/// 🔑 GENERATE KEY (ADMIN API)
app.get('/generate', (req, res) => {

  const key = uuidv4().split('-').join('').substring(0,12).toUpperCase();

  licenses[key] = {
    device_id: null,
    status: "active"
  };

  res.json({ key });
});

/// 🔐 ACTIVATE LICENSE
app.post('/activate', (req, res) => {

  const { key, device_id } = req.body;

  if (!licenses[key]) {
    return res.json({ status: "invalid" });
  }

  /// First time activation
  if (licenses[key].device_id === null) {
    licenses[key].device_id = device_id;
    return res.json({ status: "activated" });
  }

  /// Same device
  if (licenses[key].device_id === device_id) {
    return res.json({ status: "valid" });
  }

  /// Different device
  return res.json({ status: "used_on_other_device" });
});


/// 🔍 CHECK LICENSE (optional)
app.post('/check', (req, res) => {

  const { key, device_id } = req.body;

  if (!licenses[key]) {
    return res.json({ status: "invalid" });
  }

  if (licenses[key].device_id === device_id) {
    return res.json({ status: "valid" });
  }

  return res.json({ status: "invalid" });
});

const PORT = process.env.PORT || 4000;

app.listen(PORT, () => {
  console.log("🚀 License server running on port " + PORT);
=======
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
    createdAt: new Date()
  });

  res.json({ key, expiry: expiryDate, type });
});


/// 🔐 ACTIVATE
app.post('/activate', async (req, res) => {

  const { key, device_id } = req.body;

  const doc = await db.collection('licenses').doc(key).get();

  if (!doc.exists) return res.json({ status: "invalid" });

  const data = doc.data();

  if (data.status === "revoked") return res.json({ status: "revoked" });

  if (data.expiry && new Date() > data.expiry.toDate()) return res.json({ status: "expired" });

  if (data.device_id === null) {
    await doc.ref.update({ device_id });
    return res.json({ status: "activated" });
  }

  if (data.device_id === device_id) return res.json({ status: "valid" });

  return res.json({ status: "used_on_other_device" });
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
>>>>>>> 6dd3c309672bef98506d628bfa2ab7a9624a94de
});