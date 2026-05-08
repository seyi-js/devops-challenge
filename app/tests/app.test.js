const request = require('supertest');
const app = require('../src/index');

describe('GET /', () => {
  it('returns status ok and version', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body).toHaveProperty('version');
  });
});

describe('GET /health', () => {
  it('returns healthy true', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.healthy).toBe(true);
  });
});

describe('GET /metrics', () => {
  it('returns uptime, request_count, and memory_mb', async () => {
    const res = await request(app).get('/metrics');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('uptime_seconds');
    expect(res.body).toHaveProperty('request_count');
    expect(res.body).toHaveProperty('memory_mb');
    expect(typeof res.body.uptime_seconds).toBe('number');
    expect(typeof res.body.request_count).toBe('number');
  });
});
