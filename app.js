// Import express framework
const express = require('express');
const path = require('path');
const { initializeDatabase, query } = require('./database/connection');

// Initialize express application
const app = express();
// Define port from environment variable or default to 5000
const port = process.env.PORT || 5000;

// Record the time when the application was started
const deploymentTime = new Date().toISOString();
// Define application version from environment variable or default to 1.1.0
const version = process.env.APP_VERSION || '1.1.0';

// Database connection flag
let useDatabase = false;

// Initialize database on startup
initializeDatabase()
    .then(() => {
        useDatabase = true;
        console.log('✅ Using PostgreSQL for persistent storage');
    })
    .catch((error) => {
        console.log('⚠️  Using in-memory storage (development mode)');
        useDatabase = false;
    });

// Mock Data for the Mail System
let activities = [
    { type: 'login', user: 'user@example.com', timestamp: new Date(Date.now() - 3600000).toISOString(), detail: 'Successful login from IP 192.168.1.1' },
    { type: 'deploy', user: 'system', timestamp: new Date(Date.now() - 7200000).toISOString(), detail: 'Version 1.1.0 deployed successfully' }
];

function logActivity(type, user, detail) {
    activities.unshift({
        type,
        user,
        detail,
        timestamp: new Date().toISOString()
    });
    if (activities.length > 50) activities.pop();
}

let emails = [
    {
        id: '1',
        from: 'system@gitops.lab',
        to: 'user@example.com',
        subject: 'Welcome to the GitOps Mail System',
        body: 'Welcome to your new secure email system. This application is deployed via a hardened CI/CD pipeline.',
        date: new Date(Date.now() - 3600000).toISOString(),
        read: false,
        folder: 'inbox',
        starred: true
    },
    {
        id: '2',
        from: 'security-bot@gitops.lab',
        to: 'user@example.com',
        subject: 'Security Scan Completed',
        body: 'Great news! Your latest deployment passed all security gates. No critical or high vulnerabilities were found.',
        date: new Date(Date.now() - 7200000).toISOString(),
        read: true,
        folder: 'inbox',
        starred: false
    },
    {
        id: '3',
        from: 'user@example.com',
        to: 'manager@example.com',
        subject: 'Project Update: GitOps Lab',
        body: 'The GitOps lab is progressing well. I have just implemented the in-depth mail system module.',
        date: new Date(Date.now() - 86400000).toISOString(),
        read: true,
        folder: 'sent',
        starred: true
    }
];

// Middleware to parse JSON bodies
app.use(express.json());
// Middleware to serve static files from 'public' directory
app.use(express.static(path.join(__dirname, 'public')));

// API Endpoints for Mail System

// Get all emails
app.get('/api/emails', async (req, res) => {
    try {
        if (useDatabase) {
            const result = await query('SELECT * FROM emails ORDER BY created_at DESC');
            const emails = result.rows.map(row => ({
                id: row.id.toString(),
                from: row.sender,
                to: row.recipient,
                subject: row.subject,
                body: row.body,
                date: row.created_at,
                read: row.is_read,
                folder: row.folder,
                starred: row.is_starred
            }));
            res.json(emails);
        } else {
            res.json(emails);
        }
    } catch (error) {
        console.error('Error fetching emails:', error);
        res.status(500).json({ error: 'Failed to fetch emails' });
    }
});

// Get email by ID
app.get('/api/emails/:id', (req, res) => {
    const email = emails.find(e => e.id === req.params.id);
    if (!email) return res.status(404).json({ error: 'Email not found' });
    res.json(email);
});

// Send a new email or save a draft
app.post('/api/emails', async (req, res) => {
    const { to, subject, body, folder } = req.body;
    if (!to && !subject && !body) {
        return res.status(400).json({ error: 'Cannot save an empty email' });
    }
    
    try {
        if (useDatabase) {
            const result = await query(
                'INSERT INTO emails (sender, recipient, subject, body, folder, is_read) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
                ['user@example.com', to || '', subject || '(No Subject)', body || '', folder || 'sent', true]
            );
            
            const newEmail = {
                id: result.rows[0].id.toString(),
                from: result.rows[0].sender,
                to: result.rows[0].recipient,
                subject: result.rows[0].subject,
                body: result.rows[0].body,
                date: result.rows[0].created_at,
                read: result.rows[0].is_read,
                folder: result.rows[0].folder,
                starred: result.rows[0].is_starred
            };
            
            await query(
                'INSERT INTO activity_logs (action, details) VALUES ($1, $2)',
                ['email_sent', `Sent email to ${to}: ${subject}`]
            );
            
            res.status(201).json(newEmail);
        } else {
            const newEmail = {
                id: (emails.length + 1).toString(),
                from: 'user@example.com',
                to: to || '',
                subject: subject || '(No Subject)',
                body: body || '',
                date: new Date().toISOString(),
                read: true,
                folder: folder || 'sent',
                starred: false
            };
            
            emails.push(newEmail);
            logActivity('email_sent', 'user@example.com', `Sent email to ${to}: ${subject}`);
            res.status(201).json(newEmail);
        }
    } catch (error) {
        console.error('Error creating email:', error);
        res.status(500).json({ error: 'Failed to create email' });
    }
});

// Update an existing email (for drafts)
app.put('/api/emails/:id', (req, res) => {
    const email = emails.find(e => e.id === req.params.id);
    if (!email) return res.status(404).json({ error: 'Email not found' });
    
    const { to, subject, body, folder } = req.body;
    const oldFolder = email.folder;
    
    if (to !== undefined) email.to = to;
    if (subject !== undefined) email.subject = subject;
    if (body !== undefined) email.body = body;
    if (folder !== undefined) email.folder = folder;
    
    email.date = new Date().toISOString();
    
    if (oldFolder === 'drafts' && folder === 'sent') {
        logActivity('email_sent', 'user@example.com', `Sent draft email to ${email.to}: ${email.subject}`);
    } else if (folder === 'drafts') {
        logActivity('draft_updated', 'user@example.com', `Updated draft: ${email.subject}`);
    }
    
    res.json(email);
});

// Mark email as read
app.put('/api/emails/:id/read', (req, res) => {
    const email = emails.find(e => e.id === req.params.id);
    if (!email) return res.status(404).json({ error: 'Email not found' });
    
    email.read = true;
    res.json(email);
});

// Toggle star status
app.put('/api/emails/:id/star', (req, res) => {
    const email = emails.find(e => e.id === req.params.id);
    if (!email) return res.status(404).json({ error: 'Email not found' });
    
    email.starred = !email.starred;
    res.json(email);
});

// Delete an email (move to trash or permanent delete)
app.delete('/api/emails/:id', (req, res) => {
    const index = emails.findIndex(e => e.id === req.params.id);
    if (index === -1) return res.status(404).json({ error: 'Email not found' });
    
    const email = emails[index];
    if (email.folder === 'trash') {
        logActivity('email_deleted_permanent', 'user@example.com', `Permanently deleted email: ${email.subject}`);
        emails.splice(index, 1);
        res.json({ message: 'Email permanently deleted' });
    } else {
        logActivity('email_trashed', 'user@example.com', `Moved email to trash: ${email.subject}`);
        email.folder = 'trash';
        res.json({ message: 'Email moved to trash' });
    }
});

// Activity Logs API
app.get('/api/activities', (req, res) => {
    res.json(activities);
});


// System Information
app.get('/api/info', (req, res) => {
    res.json({
        version,
        deploymentTime,
        uptime: process.uptime(),
        platform: process.platform,
        nodeVersion: process.version,
        status: "running",
        env: {
            PORT: port,
            NODE_ENV: process.env.NODE_ENV || 'production'
        },
        stats: {
            totalEmails: useDatabase ? 'N/A (database)' : emails.length,
            unreadCount: useDatabase ? 'N/A (database)' : emails.filter(e => e.folder === 'inbox' && !e.read).length,
            starredCount: useDatabase ? 'N/A (database)' : emails.filter(e => e.starred).length,
            storageType: useDatabase ? 'PostgreSQL (persistent)' : 'In-memory (development)'
        },
        scanResults: {
            sast: { status: 'passed', vulnerabilities: 0, lastRun: new Date(Date.now() - 86400000).toISOString() },
            sca: { status: 'passed', vulnerabilities: 2, lastRun: new Date(Date.now() - 86400000).toISOString() },
            image: { status: 'passed', vulnerabilities: 5, lastRun: new Date(Date.now() - 86400000).toISOString() },
            secrets: { status: 'passed', found: 0, lastRun: new Date(Date.now() - 86400000).toISOString() }
        }
    });
});




// Health check endpoint for monitoring
app.get('/health', (req, res) => {
    res.status(200).json({
        status: "healthy",
        timestamp: new Date().toISOString()
    });
});

// Fallback to index.html for SPA routing
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Start the server if the script is run directly
if (require.main === module) {
    app.listen(port, '0.0.0.0', () => {
        console.log(`Mail System Server running on port ${port}`);
        console.log(`Version: ${version}`);
    });
}

// Export app for testing purposes
module.exports = app;