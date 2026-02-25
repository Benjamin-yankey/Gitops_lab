document.addEventListener('DOMContentLoaded', () => {
    // State
    let currentFolder = 'inbox';
    let emails = [];
    let selectedEmailId = null;

    // DOM Elements
    const emailsContainer = document.getElementById('emails-container');
    const emailDetail = document.getElementById('email-detail');
    const navItems = document.querySelectorAll('.nav-item');
    const folderTitle = document.getElementById('current-folder-title');
    const inboxBadge = document.getElementById('inbox-badge');
    const refreshBtn = document.getElementById('refresh-btn');
    const composeBtn = document.getElementById('compose-btn');
    const composeModal = document.getElementById('compose-modal');
    const closeModal = document.querySelector('.close-modal');
    const composeForm = document.getElementById('compose-form');
    const searchInput = document.getElementById('search-input');
    const appVersion = document.getElementById('app-version');
    const deploymentInfo = document.getElementById('deployment-info');

    // Initialization
    fetchEmails();
    fetchSystemInfo();

    // Event Listeners
    navItems.forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            navItems.forEach(i => i.classList.remove('active'));
            item.classList.add('active');
            currentFolder = item.dataset.folder;
            folderTitle.textContent = currentFolder.charAt(0).toUpperCase() + currentFolder.slice(1);
            renderEmailList();
        });
    });

    refreshBtn.addEventListener('click', fetchEmails);

    composeBtn.addEventListener('click', () => composeModal.style.display = 'block');
    closeModal.addEventListener('click', () => composeModal.style.display = 'none');
    window.addEventListener('click', (e) => {
        if (e.target === composeModal) composeModal.style.display = 'none';
    });

    composeForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const to = document.getElementById('email-to').value;
        const subject = document.getElementById('email-subject').value;
        const body = document.getElementById('email-body').value;
        const isDraft = e.submitter.id === 'save-draft-btn';

        // Validation: Send requires all fields, Draft requires at least one
        if (!isDraft && (!to || !subject || !body)) {
            showNotification('Please fill in all fields to send.');
            return;
        }
        if (isDraft && !to && !subject && !body) {
            showNotification('Cannot save an empty draft.');
            return;
        }

        try {
            const response = await fetch('/api/emails', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ 
                    to, 
                    subject, 
                    body, 
                    folder: isDraft ? 'drafts' : 'sent' 
                })
            });


            if (response.ok) {
                composeModal.style.display = 'none';
                composeForm.reset();
                fetchEmails();
                showNotification(isDraft ? 'Draft saved' : 'Email sent successfully!');
            }
        } catch (error) {
            console.error('Error sending email:', error);
        }
    });

    searchInput.addEventListener('input', () => {
        renderEmailList();
    });

    // Functions
    async function fetchEmails() {
        emailsContainer.innerHTML = '<div class="loading-state">Syncing emails...</div>';
        try {
            const response = await fetch('/api/emails');
            emails = await response.json();
            renderEmailList();
            updateUnreadCount();
        } catch (error) {
            console.error('Error fetching emails:', error);
            emailsContainer.innerHTML = '<div class="error-state">Failed to load emails</div>';
        }
    }

    async function fetchSystemInfo() {
        try {
            const response = await fetch('/api/info');
            const info = await response.json();
            appVersion.textContent = `v${info.version}`;
            deploymentInfo.textContent = `Deployed: ${new Date(info.deploymentTime).toLocaleString()}`;
        } catch (error) {
            console.log('Error fetching system info');
        }
    }

    function renderEmailList() {
        const searchTerm = searchInput.value.toLowerCase();
        
        if (currentFolder === 'settings') {
            renderSettings();
            return;
        }

        if (currentFolder === 'logs') {
            renderLogs();
            return;
        }

        let filteredEmails = [];
        
        if (currentFolder === 'starred') {
            filteredEmails = emails.filter(email => email.starred && email.folder !== 'trash');
        } else {
            filteredEmails = emails.filter(email => email.folder === currentFolder);
        }

        if (searchTerm) {
            filteredEmails = filteredEmails.filter(email => 
                email.subject.toLowerCase().includes(searchTerm) || 
                email.from.toLowerCase().includes(searchTerm) || 
                email.body.toLowerCase().includes(searchTerm)
            );
        }

        if (filteredEmails.length === 0) {
            emailsContainer.innerHTML = '<div class="empty-state">No emails in this folder</div>';
            return;
        }

        emailsContainer.innerHTML = '';
        filteredEmails.sort((a, b) => new Date(b.date) - new Date(a.date)).forEach(email => {
            const item = document.createElement('div');
            item.className = `email-item ${!email.read ? 'unread' : ''} ${selectedEmailId === email.id ? 'selected' : ''}`;
            item.innerHTML = `
                <div class="email-meta">
                    <span class="from">${currentFolder === 'sent' || currentFolder === 'drafts' ? 'To: ' + (email.to || '(No recipient)') : email.from}</span>
                    <div style="display: flex; align-items: center; gap: 8px;">
                        ${email.starred ? '<span class="star-icon active">★</span>' : ''}
                        <span class="date">${formatDate(email.date)}</span>
                    </div>
                </div>
                <div class="subject">${email.subject}</div>
                <div class="snippet">${email.body}</div>
            `;
            item.addEventListener('click', () => selectEmail(email));
            emailsContainer.appendChild(item);
        });
    }

    async function renderLogs() {
        emailsContainer.innerHTML = '<div class="loading-state">Fetching activity logs...</div>';
        try {
            const response = await fetch('/api/activities');
            const logs = await response.json();
            
            emailsContainer.innerHTML = logs.map(log => `
                <div class="email-item" style="cursor: default; border-left: 4px solid var(--accent-color);">
                    <div class="email-meta">
                        <span class="from" style="color: var(--accent-color); font-weight: 600;">${log.type.toUpperCase()}</span>
                        <span class="date">${new Date(log.timestamp).toLocaleTimeString()}</span>
                    </div>
                    <div class="subject" style="font-size: 0.875rem;">${log.detail}</div>
                    <div class="snippet">${log.user} • ${new Date(log.timestamp).toLocaleDateString()}</div>
                </div>
            `).join('');
            
            emailDetail.innerHTML = `
                <div class="logs-detail-view" style="padding: 40px;">
                    <div class="detail-header" style="text-align: center; margin-bottom: 40px;">
                        <div style="width: 80px; height: 80px; background: var(--selection-bg); border-radius: 20px; display: flex; align-items: center; justify-content: center; margin: 0 auto 24px;">
                            <svg viewBox="0 0 24 24" width="40" height="40" stroke="var(--accent-color)" stroke-width="2" fill="none"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg>
                        </div>
                        <h2>Audit Trail</h2>
                        <p style="color: var(--text-secondary);">Security and system activity logs for compliance</p>
                    </div>
                    
                    <div class="log-info-box" style="background: var(--selection-bg); padding: 32px; border-radius: 16px; border: 1px solid var(--border-color);">
                        <h4 style="margin-bottom: 24px;">Log Summary</h4>
                        <div style="display: flex; flex-direction: column; gap: 16px;">
                            <div style="display: flex; justify-content: space-between;">
                                <span style="color: var(--text-secondary);">Total Log Entries:</span>
                                <span>${logs.length}</span>
                            </div>
                            <div style="display: flex; justify-content: space-between;">
                                <span style="color: var(--text-secondary);">Last Activity:</span>
                                <span>${logs[0] ? new Date(logs[0].timestamp).toLocaleString() : 'N/A'}</span>
                            </div>
                            <div style="display: flex; justify-content: space-between;">
                                <span style="color: var(--text-secondary);">System Status:</span>
                                <span style="color: #22c55e; font-weight: 600;">SECURE</span>
                            </div>
                        </div>
                    </div>
                    
                    <div style="margin-top: 40px; text-align: center;">
                        <button class="btn" style="border: 1px solid var(--border-color);" onclick="window.print()">Export Audit PDF</button>
                    </div>
                </div>
            `;
        } catch (error) {
            console.error('Error loading logs:', error);
        }
    }


    async function renderSettings(tab = 'diagnostics') {
        emailsContainer.innerHTML = '<div class="loading-state">Loading settings...</div>';
        try {
            const response = await fetch('/api/info');
            const data = await response.json();
            
            let tabContent = '';
            
            if (tab === 'diagnostics') {
                tabContent = `
                    <div class="diagnostics-grid" style="display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-top: 32px;">
                        <div class="diag-card" style="background: var(--selection-bg); padding: 20px; border-radius: 12px; border: 1px solid var(--border-color);">
                            <h4 style="margin-bottom: 16px; color: var(--accent-color);">System Info</h4>
                            <div style="display: flex; flex-direction: column; gap: 8px; font-size: 0.9rem;">
                                <div><span style="color: var(--text-secondary);">App Version:</span> ${data.version}</div>
                                <div><span style="color: var(--text-secondary);">Node Version:</span> ${data.nodeVersion}</div>
                                <div><span style="color: var(--text-secondary);">Platform:</span> ${data.platform}</div>
                                <div><span style="color: var(--text-secondary);">Uptime:</span> ${Math.floor(data.uptime / 60)} minutes</div>
                            </div>
                        </div>
                        
                        <div class="diag-card" style="background: var(--selection-bg); padding: 20px; border-radius: 12px; border: 1px solid var(--border-color);">
                            <h4 style="margin-bottom: 16px; color: var(--accent-color);">Deployment</h4>
                            <div style="display: flex; flex-direction: column; gap: 8px; font-size: 0.9rem;">
                                <div><span style="color: var(--text-secondary);">Time:</span> ${new Date(data.deploymentTime).toLocaleString()}</div>
                                <div><span style="color: var(--text-secondary);">Environment:</span> ${data.env.NODE_ENV}</div>
                                <div><span style="color: var(--text-secondary);">Internal Port:</span> ${data.env.PORT}</div>
                                <div><span style="color: var(--text-secondary);">Status:</span> <span style="color: #22c55e;">Online</span></div>
                            </div>
                        </div>
                    </div>
                `;
            } else if (tab === 'security') {
                tabContent = `
                    <div class="security-grid" style="display: flex; flex-direction: column; gap: 16px; margin-top: 32px;">
                        ${Object.entries(data.scanResults).map(([key, scan]) => `
                            <div class="scan-card" style="background: var(--selection-bg); padding: 20px; border-radius: 12px; border: 1px solid var(--border-color); display: flex; align-items: center; justify-content: space-between;">
                                <div>
                                    <h4 style="text-transform: uppercase; margin-bottom: 4px;">${key} Analysis</h4>
                                    <span style="font-size: 0.8rem; color: var(--text-secondary);">Last run: ${new Date(scan.lastRun).toLocaleString()}</span>
                                </div>
                                <div style="text-align: right;">
                                    <div style="color: #22c55e; font-weight: 600; font-size: 0.9rem; margin-bottom: 4px;">● PASSED</div>
                                    <span style="font-size: 0.8rem; color: var(--text-secondary);">${scan.vulnerabilities !== undefined ? scan.vulnerabilities + ' vulnerabilities' : scan.found + ' secrets'} found</span>
                                </div>
                            </div>
                        `).join('')}
                    </div>
                `;
            }

            emailDetail.innerHTML = `
                <div class="settings-view">
                    <div class="detail-header">
                        <h2>${tab === 'diagnostics' ? 'System Diagnostics' : 'Security Compliance'}</h2>
                        <p style="color: var(--text-secondary);">${tab === 'diagnostics' ? 'Operational status and environment details' : 'Last pipeline security scan results'}</p>
                    </div>
                    
                    ${tabContent}
                    
                    ${tab === 'diagnostics' ? `
                    <div class="diag-card" style="background: var(--selection-bg); padding: 20px; border-radius: 12px; border: 1px solid var(--border-color); margin-top: 24px;">
                        <h4 style="margin-bottom: 16px; color: var(--accent-color);">Account Stats</h4>
                        <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; text-align: center;">
                            <div>
                                <div style="font-size: 1.5rem; font-weight: 700;">${data.stats.totalEmails}</div>
                                <div style="font-size: 0.75rem; color: var(--text-secondary);">Total Emails</div>
                            </div>
                            <div>
                                <div style="font-size: 1.5rem; font-weight: 700;">${data.stats.unreadCount}</div>
                                <div style="font-size: 0.75rem; color: var(--text-secondary);">Unread</div>
                            </div>
                            <div>
                                <div style="font-size: 1.5rem; font-weight: 700;">${data.stats.starredCount}</div>
                                <div style="font-size: 0.75rem; color: var(--text-secondary);">Starred</div>
                            </div>
                        </div>
                    </div>
                    ` : ''}
                    
                    <div style="margin-top: 40px; padding-top: 24px; border-top: 1px solid var(--border-color);">
                        <button class="btn" style="background: #ef4444; color: white;" onclick="alert('Action not allowed in demo mode.')">Reset All Data</button>
                    </div>
                </div>
            `;
            
            emailsContainer.innerHTML = `
                <div style="padding: 24px;">
                    <h3 style="font-size: 1rem; margin-bottom: 16px;">Settings</h3>
                    <div class="settings-nav-item ${tab === 'diagnostics' ? 'active' : ''}" data-tab="diagnostics" style="padding: 10px 16px; border-radius: 8px; margin-bottom: 8px; cursor: pointer;">Diagnostics</div>
                    <div class="settings-nav-item ${tab === 'security' ? 'active' : ''}" data-tab="security" style="padding: 10px 16px; border-radius: 8px; margin-bottom: 8px; cursor: pointer;">Security Scans</div>
                    <div class="settings-nav-item" style="padding: 10px 16px; border-radius: 8px; margin-bottom: 8px; opacity: 0.5;">Account</div>
                    <div class="settings-nav-item" style="padding: 10px 16px; border-radius: 8px; opacity: 0.5;">Notifications</div>
                </div>
            `;

            emailsContainer.querySelectorAll('.settings-nav-item').forEach(item => {
                if (item.dataset.tab) {
                    item.addEventListener('click', () => renderSettings(item.dataset.tab));
                }
            });
            
        } catch (error) {
            console.error('Error loading settings:', error);
        }
    }



    async function selectEmail(email) {
        selectedEmailId = email.id;
        renderEmailList(); // Update selected state in list

        if (email.folder === 'drafts') {
            openDraft(email);
            return;
        }

        // Mark as read if it was unread
        if (!email.read) {
            try {
                await fetch(`/api/emails/${email.id}/read`, { method: 'PUT' });
                email.read = true;
                updateUnreadCount();
            } catch (error) {
                console.error('Error marking as read');
            }
        }

        emailDetail.innerHTML = `
            <div class="email-full-view">
                <div class="detail-header">
                    <div style="display: flex; justify-content: space-between; align-items: flex-start;">
                        <h2>${email.subject}</h2>
                        <button class="btn-icon star-toggle ${email.starred ? 'active' : ''}" id="star-btn">
                            <svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="2" fill="${email.starred ? 'var(--accent-color)' : 'none'}" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon></svg>
                        </button>
                    </div>
                    <div class="detail-meta">
                        <div class="avatar">${email.from.substring(0, 2).toUpperCase()}</div>
                        <div class="detail-info">
                            <span class="name">${email.from.split('@')[0]}</span>
                            <span class="address">&lt;${email.from}&gt;</span>
                        </div>
                        <span class="date">${new Date(email.date).toLocaleString()}</span>
                    </div>
                </div>
                <div class="email-body">${email.body}</div>
                <div class="email-actions" style="margin-top: 40px; border-top: 1px solid var(--border-color); padding-top: 24px;">
                    <button class="btn btn-icon delete-btn" style="color: #ef4444;">
                        <svg viewBox="0 0 24 24" width="18" height="18" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></svg>
                        &nbsp; ${email.folder === 'trash' ? 'Delete Permanently' : 'Delete'}
                    </button>
                </div>
            </div>
        `;

        document.getElementById('star-btn').addEventListener('click', async () => {
            try {
                const response = await fetch(`/api/emails/${email.id}/star`, { method: 'PUT' });
                const updated = await response.json();
                email.starred = updated.starred;
                selectEmail(email); // Re-render detail
                renderEmailList();  // Re-render list
            } catch (error) {
                console.error('Error toggling star');
            }
        });

        emailDetail.querySelector('.delete-btn').addEventListener('click', async () => {
            const msg = email.folder === 'trash' ? 'Permanently delete this email?' : 'Move this email to trash?';
            if (confirm(msg)) {
                await fetch(`/api/emails/${email.id}`, { method: 'DELETE' });
                emailDetail.innerHTML = `<div class="empty-detail-state"><p>${email.folder === 'trash' ? 'Email deleted' : 'Email moved to trash'}</p></div>`;
                fetchEmails();
            }
        });
    }

    function openDraft(email) {
        composeModal.style.display = 'block';
        document.getElementById('email-to').value = email.to || '';
        document.getElementById('email-subject').value = email.subject || '';
        document.getElementById('email-body').value = email.body || '';
        
        // Temporarily change form handling for this specific draft
        const originalSubmitHandler = composeForm.onsubmit;
        composeForm.onsubmit = async (e) => {
            e.preventDefault();
            const to = document.getElementById('email-to').value;
            const subject = document.getElementById('email-subject').value;
            const body = document.getElementById('email-body').value;
            const isDraft = e.submitter.id === 'save-draft-btn';

            // Validation
            if (!isDraft && (!to || !subject || !body)) {
                showNotification('Please fill in all fields to send.');
                return;
            }
            if (isDraft && !to && !subject && !body) {
                showNotification('Cannot save an empty draft.');
                return;
            }

            try {
                const response = await fetch(`/api/emails/${email.id}`, {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ 
                        to, 
                        subject, 
                        body, 
                        folder: isDraft ? 'drafts' : 'sent' 
                    })
                });


                if (response.ok) {
                    composeModal.style.display = 'none';
                    composeForm.reset();
                    composeForm.onsubmit = null; // Revert to listener
                    fetchEmails();
                    showNotification(isDraft ? 'Draft updated' : 'Email sent successfully!');
                }
            } catch (error) {
                console.error('Error updating draft:', error);
            }
        };
    }


    function updateUnreadCount() {
        const unread = emails.filter(e => e.folder === 'inbox' && !e.read).length;
        inboxBadge.textContent = unread;
        inboxBadge.style.display = unread > 0 ? 'inline-block' : 'none';
    }

    function formatDate(dateStr) {
        const date = new Date(dateStr);
        const now = new Date();
        if (date.toDateString() === now.toDateString()) {
            return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        }
        return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
    }

    function showNotification(text) {
        const notif = document.createElement('div');
        notif.style.cssText = `
            position: fixed;
            bottom: 32px;
            right: 32px;
            background: #22c55e;
            color: #0f172a;
            padding: 12px 24px;
            border-radius: 12px;
            font-weight: 600;
            box-shadow: 0 10px 20px rgba(0,0,0,0.2);
            z-index: 1000;
            animation: slideUp 0.3s ease-out;
        `;
        notif.textContent = text;
        document.body.appendChild(notif);
        setTimeout(() => {
            notif.style.animation = 'slideDown 0.3s ease-in';
            setTimeout(() => notif.remove(), 300);
        }, 3000);
    }
});

// Animations
const style = document.createElement('style');
style.textContent = `
    @keyframes slideUp {
        from { transform: translateY(100%); opacity: 0; }
        to { transform: translateY(0); opacity: 1; }
    }
    @keyframes slideDown {
        from { transform: translateY(0); opacity: 1; }
        to { transform: translateY(100%); opacity: 0; }
    }
`;
document.head.appendChild(style);
