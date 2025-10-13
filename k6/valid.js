import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '20s', target: 50 },
    { duration: '40s', target: 200 },
    { duration: '20s', target: 0 },
  ],
};

const MODE = __ENV.MODE || 'gw'; // 'gw' or 'base'
const BASE = MODE === 'gw' ? 'http://localhost:8000' : 'http://localhost:3000';

export default function () {
  const login = http.post(`${BASE}/auth/login`, JSON.stringify({ username: 'demo', password: 'demo123' }), {
    headers: { 'Content-Type': 'application/json' },
  });
  check(login, { 'login ok': (r) => r.status === 200 || r.status === 201 });
  const token = login.json('access_token');

  const me = http.get(`${BASE}/api/me`, { headers: { Authorization: `Bearer ${token}` } });
  check(me, { 'me 200': (r) => r.status === 200 });
  sleep(1);
}
