// =============================================================================
// KumaHost FiveM API — tests/api.test.js
// Integration tests for auth, validation, CSRF and health using supertest.
// Runs against an isolated temp database; no privileged commands are invoked.
// =============================================================================
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

// Configure an isolated environment BEFORE importing the app/config.
const tmpDb = path.join(os.tmpdir(), `kh-test-${Date.now()}.db`);
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret-value-which-is-sufficiently-long-123';
process.env.DB_PATH = tmpDb;
process.env.AUTH_RATE_MAX = '1000';
process.env.RATE_MAX = '100000';

const { default: request } = await import('supertest');
const { createApp } = await import('../src/server.js');
const { migrate } = await import('../src/db.js');
const bcrypt = (await import('bcryptjs')).default;
const { default: db } = await import('../src/db.js');

migrate();
// Seed a known admin user.
const hash = await bcrypt.hash('supersecret', 4);
db.prepare('INSERT OR REPLACE INTO users (username, password_hash, role) VALUES (?, ?, ?)').run(
  'admin',
  hash,
  'admin',
);

const app = createApp();

test.after(() => {
  for (const suffix of ['', '-wal', '-shm']) {
    try { fs.unlinkSync(tmpDb + suffix); } catch { /* ignore */ }
  }
});

test('health endpoint is public and reports ok', async () => {
  const res = await request(app).get('/api/system/health');
  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'ok');
});

test('protected route rejects unauthenticated access', async () => {
  const res = await request(app).get('/api/servers');
  assert.equal(res.status, 401);
});

test('login rejects invalid credentials', async () => {
  const res = await request(app).post('/api/auth/login').send({ username: 'admin', password: 'wrong' });
  assert.equal(res.status, 401);
});

test('login rejects malformed input with 400', async () => {
  const res = await request(app).post('/api/auth/login').send({ username: 'ab' });
  assert.equal(res.status, 400);
  assert.ok(Array.isArray(res.body.details));
});

test('login succeeds and returns a bearer token', async () => {
  const res = await request(app).post('/api/auth/login').send({ username: 'admin', password: 'supersecret' });
  assert.equal(res.status, 200);
  assert.ok(res.body.token, 'expected a JWT in the response');
  assert.equal(res.body.user.username, 'admin');
});

test('bearer token grants access to protected routes', async () => {
  const login = await request(app).post('/api/auth/login').send({ username: 'admin', password: 'supersecret' });
  const res = await request(app).get('/api/servers').set('Authorization', `Bearer ${login.body.token}`);
  assert.equal(res.status, 200);
  assert.ok(Array.isArray(res.body.servers));
  // The default server is seeded by migrate().
  assert.ok(res.body.servers.some((s) => s.name === 'default'));
});

test('cookie auth without CSRF header is rejected on mutations', async () => {
  const agent = request.agent(app);
  await agent.post('/api/auth/login').send({ username: 'admin', password: 'supersecret' });
  // Mutation via cookie auth but missing X-CSRF-Token must fail.
  const res = await agent.post('/api/servers/1/restart');
  assert.equal(res.status, 403);
});
