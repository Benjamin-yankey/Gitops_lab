// Import supertest for HTTP assertions
const request = require('supertest');
// Import the app to be tested
const app = require('./app');

// Describe the application tests
describe('App Tests', () => {
    // Test the root endpoint
    test('GET / should return HTML page', async () => {
        const response = await request(app).get('/');
        expect(response.status).toBe(200);
        expect(response.text).toContain('CI/CD Pipeline App');
    });

    // Test the health check endpoint
    test('GET /health should return healthy status', async () => {
        const response = await request(app).get('/health');
        expect(response.status).toBe(200);
        expect(response.body.status).toBe('healthy');
    });

    // Test the API info endpoint
    test('GET /api/info should return app info', async () => {
        const response = await request(app).get('/api/info');
        expect(response.status).toBe(200);
        expect(response.body).toHaveProperty('version');
        expect(response.body).toHaveProperty('status');
        expect(response.body.status).toBe('running');
    });
});