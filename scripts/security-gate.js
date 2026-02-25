// Node.js script to evaluate security scan results and enforce a quality gate
const fs = require('fs');

// Define default paths for security reports
const files = {
  sca: process.env.SCA_REPORT || 'reports/sca/npm-audit-report.json',
  image: process.env.IMAGE_REPORT || 'reports/image/trivy-image.json',
  secret: process.env.SECRET_REPORT || 'reports/secret/gitleaks-report.json'
};

// Define severity levels that will cause the gate to fail
const sevOrder = ['CRITICAL', 'HIGH'];

/**
 * Safely reads and parses a JSON file
 * @param {string} path - File path to read
 * @returns {object} - Parsed JSON object
 */
function safeReadJson(path) {
  if (!fs.existsSync(path)) {
    throw new Error(`Required report not found: ${path}`);
  }
  return JSON.parse(fs.readFileSync(path, 'utf8'));
}

/**
 * Detects and counts vulnerabilities from a report (OWASP Dependency-Check or npm audit)
 * @param {object} report - Parsed JSON report
 * @returns {object} - Counts of CRITICAL and HIGH vulnerabilities
 */
function countScaVulnerabilities(report) {
  const counts = { CRITICAL: 0, HIGH: 0 };

  // Case 1: OWASP Dependency-Check (JSON)
  if (report.dependencies && Array.isArray(report.dependencies)) {
    report.dependencies.forEach(dep => {
      if (dep.vulnerabilities && Array.isArray(dep.vulnerabilities)) {
        dep.vulnerabilities.forEach(vuln => {
          const sev = String(vuln.severity || vuln.Severity || '').toUpperCase();
          if (counts[sev] !== undefined) counts[sev]++;
        });
      }
    });
    return counts;
  }

  // Case 2: npm audit (JSON)
  if (report.metadata && report.metadata.vulnerabilities) {
    const vulns = report.metadata.vulnerabilities;
    counts.CRITICAL = vulns.critical || 0;
    counts.HIGH = vulns.high || 0;
    return counts;
  }

  // Fallback or unknown format
  console.warn('Unknown SCA report format, skipping automated vulnerability count.');
  return counts;
}

/**
 * Counts vulnerabilities from Trivy image scan report
 * @param {object} report - Parsed image scan report
 * @returns {object} - Counts of CRITICAL and HIGH vulnerabilities
 */
function countTrivy(report) {
  const counts = { CRITICAL: 0, HIGH: 0 };
  for (const result of report.Results || []) {
    for (const vuln of result.Vulnerabilities || []) {
      const sev = String(vuln.Severity || vuln.severity || '').toUpperCase();
      if (counts[sev] !== undefined) counts[sev] += 1;
    }
  }
  return counts;
}

/**
 * Counts secrets found by Gitleaks
 * @param {array} report - Parsed secret report
 * @returns {number} - Number of detected secrets
 */
function countGitleaks(report) {
  return Array.isArray(report) ? report.length : 0;
}

/**
 * Merges two vulnerability count objects
 * @param {object} a - First count object
 * @param {object} b - Second count object
 * @returns {object} - Combined counts
 */
function mergeCounts(a, b) {
  return {
    CRITICAL: (a.CRITICAL || 0) + (b.CRITICAL || 0),
    HIGH: (a.HIGH || 0) + (b.HIGH || 0)
  };
}

// Main execution block
try {
  // Load scan reports
  // Find SCA report (prefer ODC, fallback to npm audit)
  let scaPath = files.sca;
  if (!fs.existsSync(scaPath)) {
    const odcPath = 'reports/sca/dependency-check-report.json';
    if (fs.existsSync(odcPath)) {
      scaPath = odcPath;
    }
  }

  const scaReport = safeReadJson(scaPath);
  const imageReport = safeReadJson(files.image);
  const secretReport = safeReadJson(files.secret);

  // Process vulnerability data
  const scaCounts = countScaVulnerabilities(scaReport);
  const imageCounts = countTrivy(imageReport);
  const total = mergeCounts(scaCounts, imageCounts);
  const secretCount = countGitleaks(secretReport);

  // Log findings to console
  console.log(`Using SCA report: ${scaPath}`);
  console.log(`SCA vulnerabilities: critical=${scaCounts.CRITICAL}, high=${scaCounts.HIGH}`);
  console.log(`Image vulnerabilities: critical=${imageCounts.CRITICAL}, high=${imageCounts.HIGH}`);
  console.log(`Secrets detected: ${secretCount}`);

  // Determine if deployment should be blocked
  const hasBlockedVulns = sevOrder.some((sev) => total[sev] > 0);
  const hasSecrets = secretCount > 0;

  if (hasBlockedVulns || hasSecrets) {
    console.error('---------------------------------------------------------');
    console.error('❌ SECURITY GATE FAILED');
    console.error(`Reason: ${hasBlockedVulns ? 'Critical/High vulnerabilities' : ''}${hasBlockedVulns && hasSecrets ? ' and ' : ''}${hasSecrets ? 'Secrets' : ''} detected.`);
    console.error(`Summary: Critical=${total.CRITICAL}, High=${total.HIGH}, Secrets=${secretCount}`);
    console.error('---------------------------------------------------------');
    process.exit(1);
  }

  console.log('Security gate passed. No Critical/High vulnerabilities and no secrets detected.');
} catch (err) {
  // Handle file reading or parsing errors
  console.error(`Security gate execution error: ${err.message}`);
  process.exit(2);
}
