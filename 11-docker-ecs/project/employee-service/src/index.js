// HRMS employee-service — CRUD over MySQL (RDS in prod, container in local compose).
// DB host/user/name from env; password injected from Secrets Manager on ECS.
const express = require('express');
const mysql = require('mysql2/promise');

const PORT = process.env.PORT || 5000;
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'db',
  user: process.env.DB_USER || 'hrmsadmin',
  password: process.env.DB_PASSWORD || 'localpass',
  database: process.env.DB_NAME || 'hrms',
  waitForConnections: true,
  connectionLimit: 10,
});

const app = express();
app.use(express.json());

// Liveness: process is up. (Readiness could also ping the DB.)
app.get('/health', (_req, res) => res.json({ status: 'ok', service: 'employee' }));

app.get('/employees', async (_req, res) => {
  try {
    const [rows] = await pool.query('SELECT id, name, department, email FROM employees ORDER BY id');
    res.json(rows);
  } catch (e) { console.error(e); res.status(500).json({ error: 'db error' }); }
});

app.post('/employees', async (req, res) => {
  const { name, department, email } = req.body || {};
  if (!name) return res.status(400).json({ error: 'name required' });
  try {
    const [r] = await pool.query(
      'INSERT INTO employees (name, department, email) VALUES (?,?,?)',
      [name, department || null, email || null]
    );
    res.status(201).json({ id: r.insertId, name, department, email });
  } catch (e) { console.error(e); res.status(500).json({ error: 'db error' }); }
});

const server = app.listen(PORT, '0.0.0.0', () => console.log(`employee-service listening on ${PORT}`));
process.on('SIGTERM', () => { console.log('SIGTERM: draining'); server.close(() => process.exit(0)); });
