import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = { vus: 100, duration: '1m' };
const MODE = __ENV.MODE || 'gw'; // 'gw' or 'base'
const GATEWAY_HOST = __ENV.GATEWAY_HOST || 'http://localhost:8000';
const UPSTREAM_HOST = __ENV.UPSTREAM_HOST || 'http://localhost:3000';
const BASE = MODE === 'gw' ? GATEWAY_HOST : UPSTREAM_HOST;

export default function () {
  const u = `user${__ITER}@mail.com`;
  const p = `wrong-${__ITER}`;
  const res = http.post(`${BASE}/auth/login`, JSON.stringify({ username: u, password: p }), {
    headers: { 'Content-Type': 'application/json' },
  });
  check(res, { 'blocked or unauthorized': (r) => [401, 429].includes(r.status) });
  sleep(0.1);
}
