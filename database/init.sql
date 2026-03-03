-- Mail System Database Schema
-- PostgreSQL schema for persistent mail storage

-- Create emails table
CREATE TABLE IF NOT EXISTS emails (
    id SERIAL PRIMARY KEY,
    subject VARCHAR(255) NOT NULL,
    sender VARCHAR(255) NOT NULL,
    recipient VARCHAR(255) NOT NULL,
    body TEXT,
    folder VARCHAR(50) DEFAULT 'inbox',
    is_read BOOLEAN DEFAULT FALSE,
    is_starred BOOLEAN DEFAULT FALSE,
    is_draft BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create activity_logs table
CREATE TABLE IF NOT EXISTS activity_logs (
    id SERIAL PRIMARY KEY,
    action VARCHAR(100) NOT NULL,
    details TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_emails_folder ON emails(folder);
CREATE INDEX IF NOT EXISTS idx_emails_is_read ON emails(is_read);
CREATE INDEX IF NOT EXISTS idx_emails_is_starred ON emails(is_starred);
CREATE INDEX IF NOT EXISTS idx_emails_created_at ON emails(created_at);
CREATE INDEX IF NOT EXISTS idx_activity_logs_timestamp ON activity_logs(timestamp);

-- Insert sample data
INSERT INTO emails (subject, sender, recipient, body, folder, is_read, is_starred) VALUES
('Welcome to GitOps Mail System', 'system@gitops-mail.com', 'user@example.com', 'Welcome to our secure mail system powered by GitOps CI/CD!', 'inbox', false, true),
('Security Alert: Pipeline Deployed', 'security@gitops-mail.com', 'user@example.com', 'Your application has been successfully deployed through our secure CI/CD pipeline.', 'inbox', false, false),
('Database Migration Complete', 'admin@gitops-mail.com', 'user@example.com', 'The mail system now uses persistent PostgreSQL storage.', 'inbox', true, false)
ON CONFLICT DO NOTHING;

-- Insert initial activity log
INSERT INTO activity_logs (action, details) VALUES
('system_init', 'Mail system database initialized with PostgreSQL')
ON CONFLICT DO NOTHING;