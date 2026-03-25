const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(cors());
app.use(bodyParser.json());

const ADMIN_KEY = process.env.ADMIN_KEY;

/// 🔥 DATABASE (can move to MongoDB later)
let licenses = {};

/// 🔑 GENERATE LICENSE (ADMIN)
app.get('/generate', (req, res) => {

  const adminKey = req.headers['admin-key'];

  if (adminKey !== ADMIN_KEY) {
    return res.status(403).json({ error: "Unauthorized" });
  }

  const key = uuidv4().split('-').join('').substring(0, 12).toUpperCase();

  /// Default expiry: 30 days
  const expiryDate = new Date();
  expiryDate.setDate(expiryDate.getDate() + 30);

  licenses[key] = {
    device_id: null,
    status: "active", // active / revoked
    expiry: expiryDate
  };

  res.json({
    key,
    expiry: expiryDate
  });
});


/// 🔐 ACTIVATE
app.post('/activate', (req, res) => {

  const { key, device_id } = req.body;

  if (!licenses[key]) {
    return res.json({ status: "invalid" });
  }

  const license = licenses[key];

  /// ❌ revoked
  if (license.status === "revoked") {
    return res.json({ status: "revoked" });
  }

  /// ⏳ expired
  if (new Date() > new Date(license.expiry)) {
    return res.json({ status: "expired" });
  }

  /// First time activation
  if (license.device_id === null) {
    license.device_id = device_id;
    return res.json({ status: "activated" });
  }

  /// Same device
  if (license.device_id === device_id) {
    return res.json({ status: "valid" });
  }

  /// ❌ different device
  return res.json({ status: "used_on_other_device" });
});


/// 🔍 CHECK LICENSE
app.post('/check', (req, res) => {

  const { key, device_id } = req.body;

  if (!licenses[key]) {
    return res.json({ status: "invalid" });
  }

  const license = licenses[key];

  if (license.status === "revoked") {
    return res.json({ status: "revoked" });
  }

  if (new Date() > new Date(license.expiry)) {
    return res.json({ status: "expired" });
  }

  if (license.device_id === device_id) {
    return res.json({ status: "valid" });
  }

  return res.json({ status: "invalid" });
});


/// ❌ REVOKE LICENSE (ADMIN)
app.post('/revoke', (req, res) => {

  const adminKey = req.headers['admin-key'];

  if (adminKey !== ADMIN_KEY) {
    return res.status(403).json({ error: "Unauthorized" });
  }

  const { key } = req.body;

  if (!licenses[key]) {
    return res.json({ status: "invalid" });
  }

  licenses[key].status = "revoked";

  return res.json({ status: "revoked_successfully" });
});


/// 📋 LIST ALL LICENSES (ADMIN)
app.get('/licenses', (req, res) => {

  const adminKey = req.headers['admin-key'];

  if (adminKey !== ADMIN_KEY) {
    return res.status(403).json({ error: "Unauthorized" });
  }

  res.json(licenses);
});


/// 🚀 SERVER START
const PORT = process.env.PORT || 4000;

app.listen(PORT, () => {
  console.log("🚀 License server running on port " + PORT);
});