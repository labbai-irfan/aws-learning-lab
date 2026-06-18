// HRMS payroll-service — computes a payslip for an employee.
// Reads salary data from MySQL; demonstrates a third independently-scaled service.
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

app.get('/health', (_req, res) => res.json({ status: 'ok', service: 'payroll' }));

app.get('/payslip/:employeeId', async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT employee_id, base_salary FROM salaries WHERE employee_id = ?',
      [req.params.employeeId]
    );
    if (!rows.length) return res.status(404).json({ error: 'no salary record' });
    const base = Number(rows[0].base_salary);
    const tax = +(base * 0.1).toFixed(2);        // simplistic 10% tax
    const net = +(base - tax).toFixed(2);
    res.json({ employeeId: rows[0].employee_id, base, tax, net });
  } catch (e) { console.error(e); res.status(500).json({ error: 'db error' }); }
});

const server = app.listen(PORT, '0.0.0.0', () => console.log(`payroll-service listening on ${PORT}`));
process.on('SIGTERM', () => { console.log('SIGTERM: draining'); server.close(() => process.exit(0)); });
