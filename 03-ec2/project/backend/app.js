// app.js — Express Todo API
// Routes are mounted under /api so Nginx can reverse-proxy "/api/" → this app.
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const pool = require('./db');

const app = express();
const PORT = process.env.PORT || 5000;

app.use(express.json());
// CORS is harmless here; in this deployment React is served same-origin via Nginx,
// so it isn't strictly required. Useful if you split the frontend onto another origin.
app.use(cors());

// Health check (used by curl / load balancer health checks)
app.get('/api/health', (req, res) => res.json({ status: 'ok', time: new Date().toISOString() }));

// List todos
app.get('/api/todos', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM todos ORDER BY created_at DESC');
    res.json(rows);
  } catch (err) {
    console.error('GET /api/todos failed:', err.message);
    res.status(500).json({ error: 'Database error' });
  }
});

// Create a todo
app.post('/api/todos', async (req, res) => {
  const { title } = req.body;
  if (!title || !title.trim()) return res.status(400).json({ error: 'title is required' });
  try {
    const [result] = await pool.query('INSERT INTO todos (title) VALUES (?)', [title.trim()]);
    const [rows] = await pool.query('SELECT * FROM todos WHERE id = ?', [result.insertId]);
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('POST /api/todos failed:', err.message);
    res.status(500).json({ error: 'Database error' });
  }
});

// Toggle done
app.put('/api/todos/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query('UPDATE todos SET done = NOT done WHERE id = ?', [id]);
    const [rows] = await pool.query('SELECT * FROM todos WHERE id = ?', [id]);
    if (rows.length === 0) return res.status(404).json({ error: 'not found' });
    res.json(rows[0]);
  } catch (err) {
    console.error('PUT /api/todos/:id failed:', err.message);
    res.status(500).json({ error: 'Database error' });
  }
});

// Delete a todo
app.delete('/api/todos/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query('DELETE FROM todos WHERE id = ?', [id]);
    res.status(204).end();
  } catch (err) {
    console.error('DELETE /api/todos/:id failed:', err.message);
    res.status(500).json({ error: 'Database error' });
  }
});

// Bind to localhost so only Nginx (same host) can reach it.
app.listen(PORT, '127.0.0.1', () => {
  console.log(`Todo API listening on http://127.0.0.1:${PORT}`);
});
