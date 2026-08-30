/**
 * Frontend tests. The BUILD pipeline runs these before producing an image,
 * so a broken frontend never gets shipped. Uses Node's built-in test runner
 * and http — no extra test dependencies.
 */
'use strict';

const { test, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('node:http');

const app = require('../server');

let server;
let base;

before(async () => {
  await new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', resolve);
  });
  const { port } = server.address();
  base = `http://127.0.0.1:${port}`;
});

after(() => server && server.close());

function get(path) {
  return new Promise((resolve, reject) => {
    http
      .get(base + path, (res) => {
        let body = '';
        res.on('data', (c) => (body += c));
        res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body }));
      })
      .on('error', reject);
  });
}

test('GET /health returns ok', async () => {
  const res = await get('/health');
  assert.strictEqual(res.status, 200);
  const json = JSON.parse(res.body);
  assert.strictEqual(json.status, 'ok');
  assert.strictEqual(json.service, 'frontend');
});

test('GET / renders the SSR home page', async () => {
  const res = await get('/');
  assert.strictEqual(res.status, 200);
  assert.match(res.body, /KadianAI/);
  // Security header from helmet config is present.
  assert.ok(res.headers['content-security-policy']);
  assert.strictEqual(res.headers['x-frame-options'], 'DENY');
});

test('unknown path returns custom 404', async () => {
  const res = await get('/definitely-not-a-page');
  assert.strictEqual(res.status, 404);
});
