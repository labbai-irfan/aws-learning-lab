import React, { useEffect, useState } from 'react';

// Calls the API at the same origin under /api/* — the ALB (prod) or Nginx (local)
// routes those to the right microservice, so there's no CORS and no hardcoded host.
export default function App() {
  const [employees, setEmployees] = useState([]);
  const [error, setError] = useState('');

  useEffect(() => {
    fetch('/api/emp/employees')
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then(setEmployees)
      .catch((e) => setError('Could not load employees: ' + e));
  }, []);

  return (
    <main style={{ fontFamily: 'system-ui', maxWidth: 720, margin: '2rem auto' }}>
      <h1>HRMS — Employees</h1>
      {error && <p style={{ color: 'crimson' }}>{error}</p>}
      <table border="1" cellPadding="8" style={{ borderCollapse: 'collapse', width: '100%' }}>
        <thead>
          <tr><th>ID</th><th>Name</th><th>Department</th><th>Email</th></tr>
        </thead>
        <tbody>
          {employees.map((e) => (
            <tr key={e.id}>
              <td>{e.id}</td><td>{e.name}</td><td>{e.department}</td><td>{e.email}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <p style={{ color: '#888' }}>auth · employee · payroll — three microservices on ECS/Fargate</p>
    </main>
  );
}
