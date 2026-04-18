import http from 'k6/http';
import { check, sleep } from 'k6';
export default function () {
  let params = {};
  if (__ENV.JWT_TOKEN) {
    params.headers = { 'Authorization': `Bearer ${__ENV.JWT_TOKEN}` };
  }
  const res = http.get('http://127.0.0.1:8080/', params);
  check(res, {
    'status is 200': (r) => r.status === 200,
  });
  sleep(0.1);
}
