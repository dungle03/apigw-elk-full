import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = { vus: 100, duration: '1m' };
const MODE = __ENV.MODE || 'gw'; // 'gw' or 'base'
const BASE = MODE === 'gw' ? 'http://localhost:8000' : 'http://localhost:3000';

export default function () {
  const u = `user${__ITER}@mail.com`;
  const p = `wrong-${__ITER}`;
  const res = http.post(`${BASE}/auth/login`, JSON.stringify({ username: u, password: p }), {
    headers: { 'Content-Type': 'application/json' },
  });
  check(res, { 'blocked or unauthorized': (r) => [401, 429].includes(r.status) });
  sleep(0.1);
}
