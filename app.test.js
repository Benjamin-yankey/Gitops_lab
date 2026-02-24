const request = require('supertest');
const app = require('./app');

describe('App Tests', () => {
    test('GET / should return HTML page', async () => {
        const response = await request(app).get('/');
        expect(response.status).toBe(200);
        expect(response.text).toContain('CI/CD Pipeline App');
    });

    test('GET /health should return healthy status', async () => {
        const response = await request(app).get('/health');
        expect(response.status).toBe(200);
        expect(response.body.status).toBe('healthy');
    });

    test('GET /api/info should return app info', async () => {
        const response = await request(app).get('/api/info');
        expect(response.status).toBe(200);
        expect(response.body).toHaveProperty('version');
        expect(response.body).toHaveProperty('status');
        expect(response.body.status).toBe('running');
    });
});