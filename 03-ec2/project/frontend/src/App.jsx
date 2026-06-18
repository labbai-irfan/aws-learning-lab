import { useEffect, useState } from 'react';

// Calls the API at the SAME origin under /api (Nginx proxies it to Node).
// This avoids CORS entirely in the EC2 deployment.
const API = '/api';

export default function App() {
  const [todos, setTodos] = useState([]);
  const [title, setTitle] = useState('');
  const [error, setError] = useState('');

  const load = async () => {
    try {
      const res = await fetch(`${API}/todos`);
      if (!res.ok) throw new Error('Failed to load');
      setTodos(await res.json());
    } catch (e) {
      setError(e.message);
    }
  };

  useEffect(() => { load(); }, []);

  const add = async (e) => {
    e.preventDefault();
    if (!title.trim()) return;
    await fetch(`${API}/todos`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title })
    });
    setTitle('');
    load();
  };

  const toggle = async (id) => {
    await fetch(`${API}/todos/${id}`, { method: 'PUT' });
    load();
  };

  const remove = async (id) => {
    await fetch(`${API}/todos/${id}`, { method: 'DELETE' });
    load();
  };

  return (
    <div style={{ maxWidth: 520, margin: '40px auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1>📝 EC2 Capstone Todo</h1>
      <p style={{ color: '#666' }}>React + Node + MySQL on Amazon EC2</p>

      <form onSubmit={add} style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Add a task..."
          style={{ flex: 1, padding: 8 }}
        />
        <button type="submit" style={{ padding: '8px 16px' }}>Add</button>
      </form>

      {error && <p style={{ color: 'crimson' }}>Error: {error}</p>}

      <ul style={{ listStyle: 'none', padding: 0 }}>
        {todos.map((t) => (
          <li key={t.id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 0' }}>
            <input type="checkbox" checked={!!t.done} onChange={() => toggle(t.id)} />
            <span style={{ flex: 1, textDecoration: t.done ? 'line-through' : 'none' }}>{t.title}</span>
            <button onClick={() => remove(t.id)}>🗑️</button>
          </li>
        ))}
      </ul>
    </div>
  );
}
