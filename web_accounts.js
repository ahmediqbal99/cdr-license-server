/// =====================================================================
/// 🌐 WEB ACCOUNTS — free / 15-day trial / licensed (cdranalyser.netlify.app)
///
/// All entitlement state lives on this server (Firestore), so clearing the
/// browser cache changes nothing: the user signs in again and gets the same
/// status back. Trial = 15 days, once per account AND once per browser
/// fingerprint. Licensed = a key from the admin panel redeemed on the
/// account, or a grant made directly from the admin panel.
/// =====================================================================

const crypto = require('crypto');

const TRIAL_DAYS = 15;

/// Checks a Google OAuth access token (from the "Continue with Google" popup)
/// really was issued to OUR client id, then returns the verified profile.
async function verifyGoogleAccessToken(accessToken, clientId) {
  const info = await (await fetch(
    'https://oauth2.googleapis.com/tokeninfo?access_token=' + encodeURIComponent(accessToken))).json();
  if (info.error || info.aud !== clientId) return null;
  const profile = await (await fetch('https://openidconnect.googleapis.com/v1/userinfo', {
    headers: { Authorization: 'Bearer ' + accessToken },
  })).json();
  if (!profile.email || profile.email_verified === false) return null;
  return { email: profile.email, name: profile.name || '' };
}

/// requireSession(req, res) -> bool: the admin dashboard's session check from server.js.
/// verifyGoogle is injectable for tests.
module.exports = function registerWebAccounts(app, db, {
  requireSession, tokenSecret,
  googleClientId = process.env.GOOGLE_CLIENT_ID || '',
  verifyGoogle = verifyGoogleAccessToken,
}) {
  const TOKEN_SECRET = tokenSecret;
  if (!TOKEN_SECRET) throw new Error('Set WEB_TOKEN_SECRET (or ADMIN_KEY) env var');

  const usersCol = () => db.collection('web_users');
  const fpCol = () => db.collection('web_trial_fingerprints');

  const normEmail = (e) => String(e || '').trim().toLowerCase();
  const validEmail = (e) => /^[^\s@/]+@[^\s@/]+\.[^\s@/]{2,}$/.test(e) && e.length <= 120;
  const toDate = (v) => (v ? (v.toDate ? v.toDate() : new Date(v)) : null);

  function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
    const hash = crypto.scryptSync(String(password), salt, 64).toString('hex');
    return { salt, hash };
  }

  function checkPassword(password, salt, hash) {
    const h = crypto.scryptSync(String(password), salt, 64);
    const stored = Buffer.from(hash, 'hex');
    return stored.length === h.length && crypto.timingSafeEqual(stored, h);
  }

  function signToken(email, sid) {
    const payload = Buffer.from(JSON.stringify({ e: email, s: sid, t: Date.now() })).toString('base64url');
    const sig = crypto.createHmac('sha256', TOKEN_SECRET).update(payload).digest('base64url');
    return `${payload}.${sig}`;
  }

  function readToken(token) {
    if (!token || !token.includes('.')) return null;
    const [payload, sig] = token.split('.');
    const expected = crypto.createHmac('sha256', TOKEN_SECRET).update(payload).digest('base64url');
    if (!sig || sig.length !== expected.length ||
        !crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) return null;
    try { return JSON.parse(Buffer.from(payload, 'base64url').toString()); } catch { return null; }
  }

  /// Simple in-memory brute-force guard for login/register (per IP).
  const attempts = new Map();
  function tooManyAttempts(ip) {
    const now = Date.now();
    const rec = attempts.get(ip) || { n: 0, since: now };
    if (now - rec.since > 15 * 60 * 1000) { rec.n = 0; rec.since = now; }
    rec.n++;
    attempts.set(ip, rec);
    return rec.n > 20;
  }

  /// What the user is entitled to right now.
  function entitlement(u) {
    const now = new Date();
    const out = {
      email: u.email,
      name: u.name || '',
      plan: 'free',
      trialAvailable: !u.trialStartedAt,
      trialEndsAt: null,
      licenseExpiry: null,
    };

    if (u.trialStartedAt) {
      const end = new Date(toDate(u.trialStartedAt).getTime());
      end.setDate(end.getDate() + TRIAL_DAYS);
      out.trialEndsAt = end.toISOString();
      if (now < end) out.plan = 'trial';
    }

    if (u.licenseKey && u.licenseStatus !== 'revoked') {
      const exp = toDate(u.licenseExpiry);
      if (!exp || now < exp) {
        out.plan = 'licensed';
        out.licenseExpiry = exp ? exp.toISOString() : 'lifetime';
      }
    }
    return out;
  }

  /// Resolves the bearer token to the user. A newer sign-in replaces the
  /// session id, so one account = one active browser at a time.
  async function requireUser(req, res, next) {
    try {
      const token = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
      const t = readToken(token);
      if (!t) return res.status(401).json({ status: 'signed_out' });
      const doc = await usersCol().doc(t.e).get();
      if (!doc.exists) return res.status(401).json({ status: 'signed_out' });
      const u = doc.data();
      if (u.disabled) return res.status(403).json({ status: 'disabled' });
      if (u.sessionId !== t.s) return res.status(401).json({ status: 'session_replaced' });

      // A key revoked in the admin panel takes effect immediately.
      if (u.licenseKey) {
        const lic = await db.collection('licenses').doc(u.licenseKey).get();
        if (!lic.exists || lic.data().status === 'revoked') u.licenseStatus = 'revoked';
      }
      req.user = u;
      req.userRef = doc.ref;
      next();
    } catch (e) {
      console.log('AUTH ERROR:', e);
      res.status(500).json({ status: 'server_error' });
    }
  }

  app.post('/web/register', async (req, res) => {
    try {
      if (tooManyAttempts(req.ip)) return res.status(429).json({ status: 'too_many_attempts' });
      const email = normEmail(req.body.email);
      const password = String(req.body.password || '');
      const name = String(req.body.name || '').trim().slice(0, 80);
      const phone = String(req.body.phone || '').trim().slice(0, 30);
      if (!validEmail(email)) return res.json({ status: 'invalid_email' });
      if (password.length < 6) return res.json({ status: 'weak_password' });

      const ref = usersCol().doc(email);
      const existing = await ref.get();
      if (existing.exists) {
        return res.json({ status: existing.data().hash ? 'email_taken' : 'use_google' });
      }

      const { salt, hash } = hashPassword(password);
      const sessionId = crypto.randomUUID();
      const user = {
        email, name, phone, salt, hash, sessionId,
        createdAt: new Date(),
        lastLoginAt: new Date(),
        lastIp: req.ip,
        trialStartedAt: null,
        trialFingerprint: null,
        licenseKey: null,
        licenseExpiry: null,
        disabled: false,
      };
      await ref.set(user);
      res.json({ status: 'ok', token: signToken(email, sessionId), account: entitlement(user) });
    } catch (e) {
      console.log('REGISTER ERROR:', e);
      res.status(500).json({ status: 'server_error' });
    }
  });

  app.post('/web/login', async (req, res) => {
    try {
      if (tooManyAttempts(req.ip)) return res.status(429).json({ status: 'too_many_attempts' });
      const email = normEmail(req.body.email);
      if (!validEmail(email)) return res.json({ status: 'wrong_credentials' });
      const doc = await usersCol().doc(email).get();
      if (!doc.exists) return res.json({ status: 'wrong_credentials' });
      const u = doc.data();
      if (!u.hash) return res.json({ status: 'use_google' }); // Google-only account
      if (!checkPassword(req.body.password || '', u.salt, u.hash)) {
        return res.json({ status: 'wrong_credentials' });
      }
      if (u.disabled) return res.json({ status: 'disabled' });

      const sessionId = crypto.randomUUID(); // signs out any other browser
      await doc.ref.update({ sessionId, lastLoginAt: new Date(), lastIp: req.ip });
      u.sessionId = sessionId;
      res.json({ status: 'ok', token: signToken(email, sessionId), account: entitlement(u) });
    } catch (e) {
      console.log('LOGIN ERROR:', e);
      res.status(500).json({ status: 'server_error' });
    }
  });

  /// Public config for the web app (the Google client id is not a secret).
  app.get('/web/config', (req, res) => {
    res.json({ googleClientId: googleClientId || null });
  });

  /// "Continue with Google": signs in, or creates the account on first use.
  /// Google has already verified the email, so an existing password account
  /// with the same email is simply signed in too.
  app.post('/web/google', async (req, res) => {
    try {
      if (tooManyAttempts(req.ip)) return res.status(429).json({ status: 'too_many_attempts' });
      if (!googleClientId) return res.json({ status: 'google_not_configured' });
      const g = await verifyGoogle(String(req.body.accessToken || ''), googleClientId);
      if (!g) return res.json({ status: 'google_failed' });

      const email = normEmail(g.email);
      const ref = usersCol().doc(email);
      const doc = await ref.get();
      const sessionId = crypto.randomUUID();
      let u;
      if (doc.exists) {
        u = doc.data();
        if (u.disabled) return res.json({ status: 'disabled' });
        await ref.update({ sessionId, lastLoginAt: new Date(), lastIp: req.ip, google: true });
        u.sessionId = sessionId;
      } else {
        u = {
          email, name: String(g.name).slice(0, 80), phone: '', salt: null, hash: null,
          google: true, sessionId,
          createdAt: new Date(), lastLoginAt: new Date(), lastIp: req.ip,
          trialStartedAt: null, trialFingerprint: null,
          licenseKey: null, licenseExpiry: null, disabled: false,
        };
        await ref.set(u);
      }
      res.json({ status: 'ok', token: signToken(email, sessionId), account: entitlement(u) });
    } catch (e) {
      console.log('GOOGLE ERROR:', e);
      res.status(500).json({ status: 'server_error' });
    }
  });

  app.get('/web/status', requireUser, (req, res) => {
    res.json({ status: 'ok', account: entitlement(req.user) });
  });

  app.post('/web/logout', requireUser, async (req, res) => {
    await req.userRef.update({ sessionId: crypto.randomUUID() });
    res.json({ status: 'ok' });
  });

  /// One trial per account AND per browser fingerprint, so a fresh email
  /// address on the same machine does not get a second trial.
  app.post('/web/start-trial', requireUser, async (req, res) => {
    try {
      const u = req.user;
      if (u.trialStartedAt) return res.json({ status: 'trial_already_used', account: entitlement(u) });

      const fp = String(req.body.fingerprint || '').replace(/[^a-zA-Z0-9]/g, '').slice(0, 64);
      if (fp) {
        const fpDoc = await fpCol().doc(fp).get();
        if (fpDoc.exists && fpDoc.data().email !== u.email) {
          return res.json({ status: 'trial_used_on_device', account: entitlement(u) });
        }
        await fpCol().doc(fp).set({ email: u.email, at: new Date() });
      }

      const now = new Date();
      await req.userRef.update({ trialStartedAt: now, trialFingerprint: fp || null });
      u.trialStartedAt = now;
      res.json({ status: 'ok', account: entitlement(u) });
    } catch (e) {
      console.log('TRIAL ERROR:', e);
      res.status(500).json({ status: 'server_error' });
    }
  });

  /// Redeem a key generated in the admin panel. The key is bound to this
  /// account (device_id = "web:<email>") so it can't be passed around.
  app.post('/web/redeem', requireUser, async (req, res) => {
    try {
      const key = String(req.body.key || '').trim().toUpperCase();
      if (!/^[A-Z0-9]{6,32}$/.test(key)) return res.json({ status: 'invalid' });
      const doc = await db.collection('licenses').doc(key).get();
      if (!doc.exists) return res.json({ status: 'invalid' });
      const lic = doc.data();
      if (lic.status === 'revoked') return res.json({ status: 'revoked' });
      // Extractor keys must not unlock the CDR Analyzer web app.
      if ((lic.product || 'cdr_analyzer') !== 'cdr_analyzer') return res.json({ status: 'wrong_product' });
      const exp = toDate(lic.expiry);
      if (exp && new Date() > exp) return res.json({ status: 'expired' });

      const owner = `web:${req.user.email}`;
      if (lic.device_id && lic.device_id !== owner) return res.json({ status: 'used_on_other_device' });

      await doc.ref.update({ device_id: owner });
      await req.userRef.update({ licenseKey: key, licenseExpiry: exp || null });
      Object.assign(req.user, { licenseKey: key, licenseExpiry: exp || null, licenseStatus: 'active' });
      res.json({ status: 'ok', account: entitlement(req.user) });
    } catch (e) {
      console.log('REDEEM ERROR:', e);
      res.status(500).json({ status: 'server_error' });
    }
  });

  /// ---------- Admin: web users ----------
  app.get('/web/users', async (req, res) => {
    if (!requireSession(req, res)) return;
    try {
      const snap = await usersCol().get();
      res.json(snap.docs.map((d) => {
        const u = d.data();
        return {
          ...entitlement(u),
          phone: u.phone || '',
          disabled: !!u.disabled,
          createdAt: toDate(u.createdAt),
          lastLoginAt: toDate(u.lastLoginAt),
        };
      }));
    } catch (e) {
      console.log('WEB USERS ERROR:', e);
      res.status(500).json({ error: 'server_error' });
    }
  });

  /// action: grant (days: 30|90|lifetime) | reset_trial | remove_license | disable | enable
  app.post('/web/users/update', async (req, res) => {
    if (!requireSession(req, res)) return;
    try {
      const email = normEmail(req.body.email);
      const ref = usersCol().doc(email);
      const doc = await ref.get();
      if (!doc.exists) return res.status(404).json({ error: 'No such user' });
      const u = doc.data();

      switch (req.body.action) {
        case 'grant': {
          const days = String(req.body.days || '30');
          const key = 'WEB' + crypto.randomBytes(5).toString('hex').toUpperCase();
          let expiry = null;
          if (days !== 'lifetime') {
            expiry = new Date();
            expiry.setDate(expiry.getDate() + (parseInt(days, 10) || 30));
          }
          await db.collection('licenses').doc(key).set({
            key, device_id: `web:${email}`, status: 'active', expiry,
            type: days, product: 'cdr_analyzer', name: u.name || email,
            createdAt: new Date(),
          });
          await ref.update({ licenseKey: key, licenseExpiry: expiry });
          break;
        }
        case 'reset_trial':
          await ref.update({ trialStartedAt: null, trialFingerprint: null });
          if (u.trialFingerprint) await fpCol().doc(u.trialFingerprint).delete();
          break;
        case 'remove_license':
          await ref.update({ licenseKey: null, licenseExpiry: null });
          break;
        case 'disable':
          await ref.update({ disabled: true, sessionId: crypto.randomUUID() });
          break;
        case 'enable':
          await ref.update({ disabled: false });
          break;
        default:
          return res.status(400).json({ error: 'Unknown action' });
      }
      res.json({ success: true });
    } catch (e) {
      console.log('ADMIN UPDATE ERROR:', e);
      res.status(500).json({ error: 'server_error' });
    }
  });
};
