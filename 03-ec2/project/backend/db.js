// db.js — MySQL connection pool (mysql2/promise)
// Reads credentials from environment (.env in dev, PM2 env / SSM in prod).
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || 'todouser',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'tododb',
  waitForConnections: true,
  connectionLimit: 10,      // tune to your instance/DB; avoid "Too many connections"
  queueLimit: 0
});

module.exports = pool;
