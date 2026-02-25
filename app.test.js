// Import supertest for HTTP assertions
const request = require('supertest');
// Import the app to be tested
const app = require('./app');

// Describe the application tests
describe('Mail System API Tests', () => {
    // Test the health check endpoint
    test('GET /health should return healthy status', async () => {
        const response = await request(app).get('/health');
        expect(response.status).toBe(200);
        expect(response.body.status).toBe('healthy');
    });

    // Test the API info endpoint
    test('GET /api/info should return app info and stats', async () => {
        const response = await request(app).get('/api/info');
        expect(response.status).toBe(200);
        expect(response.body).toHaveProperty('version');
        expect(response.body).toHaveProperty('stats');
        expect(response.body.stats).toHaveProperty('totalEmails');
    });

    // Test getting all emails
    test('GET /api/emails should return list of emails', async () => {
        const response = await request(app).get('/api/emails');
        expect(response.status).toBe(200);
        expect(Array.isArray(response.body)).toBe(true);
        expect(response.body.length).toBeGreaterThan(0);
    });

    // Test sending an email
    test('POST /api/emails should create a new email', async () => {
        const newEmail = {
            to: 'test@example.com',
            subject: 'Test Subject',
            body: 'Test Body'
        };
        const response = await request(app)
            .post('/api/emails')
            .send(newEmail);
        
        expect(response.status).toBe(201);
        expect(response.body.subject).toBe(newEmail.subject);
        expect(response.body.folder).toBe('sent');
    });

    // Test marking email as read
    test('PUT /api/emails/:id/read should mark email as read', async () => {
        const response = await request(app).put('/api/emails/1/read');
        expect(response.status).toBe(200);
        expect(response.body.read).toBe(true);
    });

    // Test toggling star status
    test('PUT /api/emails/:id/star should toggle star status', async () => {
        const getEmail = await request(app).get('/api/emails/1');
        const initialStar = getEmail.body.starred;
        
        const response = await request(app).put('/api/emails/1/star');
        expect(response.status).toBe(200);
        expect(response.body.starred).toBe(!initialStar);
    });

    // Test deleting an email (moving to trash)
    test('DELETE /api/emails/:id should move email to trash', async () => {
        const response = await request(app).delete('/api/emails/1');
        expect(response.status).toBe(200);
        expect(response.body.message).toBe('Email moved to trash');
    });

    // Test validation for empty email
    test('POST /api/emails should block empty emails', async () => {
        const response = await request(app).post('/api/emails').send({});
        expect(response.status).toBe(400);
    });

    // Test updating a draft
    test('PUT /api/emails/:id should update a draft', async () => {
        // First create a draft
        const draft = await request(app).post('/api/emails').send({
            subject: 'Draft Subject',
            folder: 'drafts'
        });
        
        const response = await request(app)
            .put(`/api/emails/${draft.body.id}`)
            .send({ subject: 'Updated Subject' });
        
        expect(response.status).toBe(200);
        expect(response.body.subject).toBe('Updated Subject');
    });

    // Test sending a draft
    test('PUT /api/emails/:id should send a draft', async () => {
        const draft = await request(app).post('/api/emails').send({
            to: 'test@example.com',
            folder: 'drafts'
        });
        
        const response = await request(app)
            .put(`/api/emails/${draft.body.id}`)
            .send({ folder: 'sent' });
        
        expect(response.status).toBe(200);
        expect(response.body.folder).toBe('sent');
    });

    // Test permanent delete
    test('DELETE /api/emails/:id should permanently delete from trash', async () => {
        // First create a new email to avoid ID conflicts
        const newEmail = await request(app).post('/api/emails').send({
            to: 'trash@example.com',
            subject: 'Delete Me',
            body: 'Soon to be gone'
        });
        const id = newEmail.body.id;

        // Move to trash
        await request(app).delete(`/api/emails/${id}`);
        
        // Then delete permanently
        const response = await request(app).delete(`/api/emails/${id}`);
        expect(response.status).toBe(200);
        expect(response.body.message).toBe('Email permanently deleted');
    });


    // Test updating a draft (reaching the draft_updated activity branch)
    test('PUT /api/emails/:id should update a draft with explicit folder', async () => {
        const draft = await request(app).post('/api/emails').send({
            subject: 'Draft Subject',
            folder: 'drafts'
        });
        
        const response = await request(app)
            .put(`/api/emails/${draft.body.id}`)
            .send({ subject: 'Updated Subject', folder: 'drafts' });
        
        expect(response.status).toBe(200);
    });

    // Test 404 cases to increase branch coverage
    test('GET /api/emails/:id should return 404 for missing email', async () => {
        const response = await request(app).get('/api/emails/999');
        expect(response.status).toBe(404);
    });

    test('PUT /api/emails/:id/read should return 404 for missing email', async () => {
        const response = await request(app).put('/api/emails/999/read');
        expect(response.status).toBe(404);
    });

    test('PUT /api/emails/:id/star should return 404 for missing email', async () => {
        const response = await request(app).put('/api/emails/999/star');
        expect(response.status).toBe(404);
    });

    test('DELETE /api/emails/:id should return 404 for missing email', async () => {
        const response = await request(app).delete('/api/emails/999');
        expect(response.status).toBe(404);
    });

    test('PUT /api/emails/:id should return 404 for missing email', async () => {
        const response = await request(app).put('/api/emails/999').send({ subject: 'test' });
        expect(response.status).toBe(404);
    });

    // Test activities API
    test('GET /api/activities should return logs', async () => {
        const response = await request(app).get('/api/activities');
        expect(response.status).toBe(200);
        expect(Array.isArray(response.body)).toBe(true);
    });

    // Test SPA fallback
    test('GET unknown route should return index.html', async () => {
        const response = await request(app).get('/some/random/route');
        expect(response.status).toBe(200);
        expect(response.headers['content-type']).toContain('text/html');
    });
});