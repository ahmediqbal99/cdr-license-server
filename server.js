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
});