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
 * @returns {object} - Findings include counts and IDs
 */
function getScaFindings(report) {
  const findings = { CRITICAL: 0, HIGH: 0, ids: [] };

  if (report.dependencies && Array.isArray(report.dependencies)) {
    report.dependencies.forEach(dep => {
      if (dep.vulnerabilities && Array.isArray(dep.vulnerabilities)) {
        dep.vulnerabilities.forEach(vuln => {
          const sev = String(vuln.severity || vuln.Severity || '').toUpperCase();
          if (findings[sev] !== undefined) {
            findings[sev]++;
            findings.ids.push(`${vuln.name || vuln.id || 'Unknown'} (SCA: ${dep.fileName || 'manifest'})`);
          }
        });
      }
    });
    return findings;
  }

  if (report.metadata && report.metadata.vulnerabilities) {
    const v = report.metadata.vulnerabilities;
    findings.CRITICAL = v.critical || 0;
    findings.HIGH = v.high || 0;
    return findings;
  }
  return findings;
}

/**
 * Counts vulnerabilities from Trivy image scan report
 * @param {object} report - Parsed image scan report
 * @returns {object} - Findings include counts and IDs
 */
function getImageFindings(report) {
  const findings = { CRITICAL: 0, HIGH: 0, ids: [] };
  for (const result of report.Results || []) {
    for (const vuln of result.Vulnerabilities || []) {
      const sev = String(vuln.Severity || vuln.severity || '').toUpperCase();
      if (findings[sev] !== undefined) {
        findings[sev]++;
        findings.ids.push(`${vuln.VulnerabilityID || vuln.id} (Image: ${vuln.PkgName || 'OS'})`);
      }
    }
  }
  return findings;
}

// Main execution block
try {
  let scaPath = files.sca;
  if (!fs.existsSync(scaPath)) {
    const odcPath = 'reports/sca/dependency-check-report.json';
    if (fs.existsSync(odcPath)) scaPath = odcPath;
  }

  const scaFindings = getScaFindings(safeReadJson(scaPath));
  const imageFindings = getImageFindings(safeReadJson(files.image));
  const secretCount = Array.isArray(safeReadJson(files.secret)) ? safeReadJson(files.secret).length : 0;

  const total = {
    CRITICAL: scaFindings.CRITICAL + imageFindings.CRITICAL,
    HIGH: scaFindings.HIGH + imageFindings.HIGH
  };
  const allIds = [...scaFindings.ids, ...imageFindings.ids];

  console.log(`Using SCA report: ${scaPath}`);
  console.log(`SCA: Critical=${scaFindings.CRITICAL}, High=${scaFindings.HIGH}`);
  console.log(`Image: Critical=${imageFindings.CRITICAL}, High=${imageFindings.HIGH}`);
  console.log(`Secrets: ${secretCount}`);

  const hasBlockedVulns = total.CRITICAL > 0 || total.HIGH > 0;
  const hasSecrets = secretCount > 0;

  if (hasBlockedVulns || hasSecrets) {
    console.error('---------------------------------------------------------');
    console.error('❌ SECURITY GATE FAILED');
    if (allIds.length > 0) {
      console.error('Blocking Vulnerabilities:');
      allIds.forEach(id => console.error(`  - ${id}`));
    }
    if (hasSecrets) console.error(`Reason: ${hasSecrets} Secret(s) detected.`);
    console.error(`Summary: Critical=${total.CRITICAL}, High=${total.HIGH}, Secrets=${secretCount}`);
    console.error('---------------------------------------------------------');
    process.exit(1);
  }

  console.log('Security gate passed. No Critical/High vulnerabilities detected.');
} catch (err) {
  console.error(`Security gate execution error: ${err.message}`);
  process.exit(2);
}
