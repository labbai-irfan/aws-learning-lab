// HRMS auth-service — issues JWTs on login, validates them.
// 12-factor: config from env, logs to stdout, stateless, graceful SIGTERM.
const express = require('express');
const jwt = require('jsonwebtoken');

const PORT = process.env.PORT || 5000;
const JWT_SECRET = process.env.JWT_SECRET || 'dev-only-change-me';

const app = express();
app.use(express.json());

// Demo user store. In production this would query the DB / an identity provider.
const USERS = { 'admin@hrms.local': { password: 'admin123', role: 'admin', id: 1 } };

app.get('/health', (_req, res) => res.json({ status: 'ok', service: 'auth' }));

app.post('/login', (req, res) => {
  const { email, password } = req.body || {};
  const user = USERS[email];
  if (!user || user.password !== password) {
    return res.status(401).json({ error: 'invalid credentials' });
  }
  const token = jwt.sign({ sub: user.id, email, role: user.role }, JWT_SECRET, { expiresIn: '1h' });
  res.json({ token, role: user.role });
});

app.get('/verify', (req, res) => {
  const auth = req.headers.authorization || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : null;
  try {
    res.json({ valid: true, claims: jwt.verify(token, JWT_SECRET) });
  } catch {
    res.status(401).json({ valid: false });
  }
});

const server = app.listen(PORT, '0.0.0.0', () => console.log(`auth-service listening on ${PORT}`));
process.on('SIGTERM', () => { console.log('SIGTERM: draining'); server.close(() => process.exit(0)); });
