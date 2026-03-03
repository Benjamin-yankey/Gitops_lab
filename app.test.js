/**
 * GitOps Mail System - Comprehensive Test Suite
 * 
 * This test suite provides complete coverage of the mail system API endpoints
 * and validates the application's functionality. It uses Jest as the testing
 * framework and Supertest for HTTP endpoint testing.
 * 
 * Test Coverage Areas:
 * - Health check endpoints for monitoring
 * - Email CRUD operations (Create, Read, Update, Delete)
 * - Email state management (read/unread, starred, folders)
 * - Activity logging and audit trails
 * - Error handling and edge cases
 * - Single Page Application (SPA) routing support
 * 
 * The tests are designed to:
 * - Achieve high code coverage (>90%)
 * - Validate API contracts and response formats
 * - Test error conditions and edge cases
 * - Ensure proper HTTP status codes
 * - Verify business logic implementation
 */

// Import testing dependencies
const request = require('supertest');  // HTTP assertion library for testing Express apps
const app = require('./app');          // Import the Express application to test

/**
 * Main Test Suite for Mail System API
 * 
 * This describe block contains all tests for the mail system functionality.
 * Tests are organized by feature area and include both positive and negative test cases.
 */
describe('Mail System API Tests', () => {
    
    /**
     * Health Check Endpoint Tests
     * 
     * These tests verify that the health check endpoint works correctly.
     * Health checks are critical for:
     * - Container orchestration (Docker, Kubernetes, ECS)
     * - Load balancer health monitoring
     * - Application monitoring and alerting
     */
    test('GET /health should return healthy status', async () => {
        const response = await request(app).get('/health');
        
        // Verify successful response
        expect(response.status).toBe(200);
        expect(response.body.status).toBe('healthy');
        expect(response.body).toHaveProperty('timestamp');
    });

    /**
     * System Information Endpoint Tests
     * 
     * Tests the /api/info endpoint which provides:
     * - Application version and deployment information
     * - Runtime statistics and system health
     * - Email system metrics
     * - Mock security scan results
     */
    test('GET /api/info should return app info and stats', async () => {
        const response = await request(app).get('/api/info');
        
        expect(response.status).toBe(200);
        
        // Verify application metadata
        expect(response.body).toHaveProperty('version');
        expect(response.body).toHaveProperty('deploymentTime');
        expect(response.body).toHaveProperty('uptime');
        expect(response.body).toHaveProperty('platform');
        expect(response.body).toHaveProperty('nodeVersion');
        
        // Verify email statistics
        expect(response.body).toHaveProperty('stats');
        expect(response.body.stats).toHaveProperty('totalEmails');
        expect(response.body.stats).toHaveProperty('unreadCount');
        expect(response.body.stats).toHaveProperty('starredCount');
        
        // Verify security scan results structure
        expect(response.body).toHaveProperty('scanResults');
        expect(response.body.scanResults).toHaveProperty('sast');
        expect(response.body.scanResults).toHaveProperty('sca');
        expect(response.body.scanResults).toHaveProperty('image');
        expect(response.body.scanResults).toHaveProperty('secrets');
    });

    /**
     * Email Retrieval Tests
     * 
     * Tests the GET /api/emails endpoint which returns all emails.
     * This endpoint is used by the frontend to populate the email list.
     */
    test('GET /api/emails should return list of emails', async () => {
        const response = await request(app).get('/api/emails');
        
        expect(response.status).toBe(200);
        expect(Array.isArray(response.body)).toBe(true);
        expect(response.body.length).toBeGreaterThan(0);
        
        // Verify email structure
        const email = response.body[0];
        expect(email).toHaveProperty('id');
        expect(email).toHaveProperty('from');
        expect(email).toHaveProperty('to');
        expect(email).toHaveProperty('subject');
        expect(email).toHaveProperty('body');
        expect(email).toHaveProperty('date');
        expect(email).toHaveProperty('read');
        expect(email).toHaveProperty('folder');
        expect(email).toHaveProperty('starred');
    });

    /**
     * Email Creation Tests
     * 
     * Tests the POST /api/emails endpoint for creating new emails.
     * This covers both sending emails and saving drafts.
     */
    test('POST /api/emails should create a new email', async () => {
        const newEmail = {
            to: 'test@example.com',
            subject: 'Test Subject',
            body: 'Test Body Content'
        };
        
        const response = await request(app)
            .post('/api/emails')
            .send(newEmail);
        
        expect(response.status).toBe(201);
        expect(response.body.subject).toBe(newEmail.subject);
        expect(response.body.to).toBe(newEmail.to);
        expect(response.body.body).toBe(newEmail.body);
        expect(response.body.folder).toBe('sent'); // Default folder for new emails
        expect(response.body.read).toBe(true);     // Sent emails are marked as read
        expect(response.body).toHaveProperty('id');
        expect(response.body).toHaveProperty('date');
    });

    /**
     * Email State Management Tests
     * 
     * These tests verify the email state management functionality:
     * - Marking emails as read/unread
     * - Starring/unstarring emails
     * - Moving emails between folders
     */
    test('PUT /api/emails/:id/read should mark email as read', async () => {
        const response = await request(app).put('/api/emails/1/read');
        
        expect(response.status).toBe(200);
        expect(response.body.read).toBe(true);
        expect(response.body.id).toBe('1');
    });

    test('PUT /api/emails/:id/star should toggle star status', async () => {
        // Get current star status
        const getEmail = await request(app).get('/api/emails/1');
        const initialStar = getEmail.body.starred;
        
        // Toggle star status
        const response = await request(app).put('/api/emails/1/star');
        
        expect(response.status).toBe(200);
        expect(response.body.starred).toBe(!initialStar); // Should be opposite of initial
        expect(response.body.id).toBe('1');
    });

    /**
     * Email Deletion Tests
     * 
     * Tests the two-stage deletion process:
     * 1. First deletion moves email to trash (soft delete)
     * 2. Second deletion permanently removes email (hard delete)
     */
    test('DELETE /api/emails/:id should move email to trash', async () => {
        const response = await request(app).delete('/api/emails/1');
        
        expect(response.status).toBe(200);
        expect(response.body.message).toBe('Email moved to trash');
    });

    test('DELETE /api/emails/:id should permanently delete from trash', async () => {
        // First create a new email to avoid ID conflicts with previous tests
        const newEmail = await request(app).post('/api/emails').send({
            to: 'trash@example.com',
            subject: 'Delete Me',
            body: 'This email will be permanently deleted'
        });
        const emailId = newEmail.body.id;

        // Move to trash (first deletion)
        const trashResponse = await request(app).delete(`/api/emails/${emailId}`);
        expect(trashResponse.body.message).toBe('Email moved to trash');
        
        // Permanently delete from trash (second deletion)
        const deleteResponse = await request(app).delete(`/api/emails/${emailId}`);
        expect(deleteResponse.status).toBe(200);
        expect(deleteResponse.body.message).toBe('Email permanently deleted');
    });

    /**
     * Email Validation Tests
     * 
     * Tests input validation and error handling for email creation.
     */
    test('POST /api/emails should block empty emails', async () => {
        const response = await request(app)
            .post('/api/emails')
            .send({}); // Empty email data
        
        expect(response.status).toBe(400);
        expect(response.body.error).toBe('Cannot save an empty email');
    });

    /**
     * Draft Management Tests
     * 
     * Tests the draft functionality including:
     * - Creating drafts
     * - Updating draft content
     * - Converting drafts to sent emails
     */
    test('PUT /api/emails/:id should update a draft', async () => {
        // Create a draft email
        const draft = await request(app).post('/api/emails').send({
            subject: 'Draft Subject',
            body: 'Draft content',
            folder: 'drafts'
        });
        
        // Update the draft
        const response = await request(app)
            .put(`/api/emails/${draft.body.id}`)
            .send({ 
                subject: 'Updated Draft Subject',
                body: 'Updated draft content'
            });
        
        expect(response.status).toBe(200);
        expect(response.body.subject).toBe('Updated Draft Subject');
        expect(response.body.body).toBe('Updated draft content');
        expect(response.body).toHaveProperty('date'); // Date should be updated
    });

    test('PUT /api/emails/:id should send a draft', async () => {
        // Create a draft
        const draft = await request(app).post('/api/emails').send({
            to: 'recipient@example.com',
            subject: 'Draft to Send',
            body: 'This draft will be sent',
            folder: 'drafts'
        });
        
        // Send the draft by changing folder to 'sent'
        const response = await request(app)
            .put(`/api/emails/${draft.body.id}`)
            .send({ folder: 'sent' });
        
        expect(response.status).toBe(200);
        expect(response.body.folder).toBe('sent');
    });

    test('PUT /api/emails/:id should update a draft with explicit folder', async () => {
        // Create a draft
        const draft = await request(app).post('/api/emails').send({
            subject: 'Draft Subject',
            folder: 'drafts'
        });
        
        // Update the draft while keeping it in drafts folder
        const response = await request(app)
            .put(`/api/emails/${draft.body.id}`)
            .send({ 
                subject: 'Updated Subject', 
                folder: 'drafts' // Explicitly keep in drafts
            });
        
        expect(response.status).toBe(200);
        expect(response.body.subject).toBe('Updated Subject');
        expect(response.body.folder).toBe('drafts');
    });

    /**
     * Error Handling Tests
     * 
     * These tests verify proper error handling for invalid requests.
     * They test 404 responses for non-existent email IDs.
     */
    test('GET /api/emails/:id should return 404 for missing email', async () => {
        const response = await request(app).get('/api/emails/999');
        expect(response.status).toBe(404);
        expect(response.body.error).toBe('Email not found');
    });

    test('PUT /api/emails/:id/read should return 404 for missing email', async () => {
        const response = await request(app).put('/api/emails/999/read');
        expect(response.status).toBe(404);
        expect(response.body.error).toBe('Email not found');
    });

    test('PUT /api/emails/:id/star should return 404 for missing email', async () => {
        const response = await request(app).put('/api/emails/999/star');
        expect(response.status).toBe(404);
        expect(response.body.error).toBe('Email not found');
    });

    test('DELETE /api/emails/:id should return 404 for missing email', async () => {
        const response = await request(app).delete('/api/emails/999');
        expect(response.status).toBe(404);
        expect(response.body.error).toBe('Email not found');
    });

    test('PUT /api/emails/:id should return 404 for missing email', async () => {
        const response = await request(app)
            .put('/api/emails/999')
            .send({ subject: 'test' });
        expect(response.status).toBe(404);
        expect(response.body.error).toBe('Email not found');
    });

    /**
     * Activity Logging Tests
     * 
     * Tests the activity logging functionality which tracks user actions
     * for audit and monitoring purposes.
     */
    test('GET /api/activities should return logs', async () => {
        const response = await request(app).get('/api/activities');
        
        expect(response.status).toBe(200);
        expect(Array.isArray(response.body)).toBe(true);
        
        // Verify activity structure if activities exist
        if (response.body.length > 0) {
            const activity = response.body[0];
            expect(activity).toHaveProperty('type');
            expect(activity).toHaveProperty('user');
            expect(activity).toHaveProperty('detail');
            expect(activity).toHaveProperty('timestamp');
        }
    });

    /**
     * Single Page Application (SPA) Support Tests
     * 
     * Tests the catch-all route that serves index.html for client-side routing.
     * This enables the frontend to handle routing without server-side redirects.
     */
    test('GET unknown route should return index.html', async () => {
        const response = await request(app).get('/some/random/route');
        
        expect(response.status).toBe(200);
        expect(response.headers['content-type']).toContain('text/html');
    });
});