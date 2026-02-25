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

// Define severity thresholds (default to 0 Critical, 20 High)
const thresholds = {
  CRITICAL: parseInt(process.env.GATE_CRITICAL_THRESHOLD || '0', 10),
  HIGH: parseInt(process.env.GATE_HIGH_THRESHOLD || '20', 10)
};

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

  console.log('---------------------------------------------------------');
  console.log('🛡️  SECURITY GATE EVALUATION');
  console.log('---------------------------------------------------------');
  console.log(`SCA Findings:   Critical=${scaFindings.CRITICAL}, High=${scaFindings.HIGH}`);
  console.log(`Image Findings: Critical=${imageFindings.CRITICAL}, High=${imageFindings.HIGH}`);
  console.log(`Secrets Found:  ${secretCount}`);
  console.log('---------------------------------------------------------');
  console.log(`Thresholds:      Critical <= ${thresholds.CRITICAL}, High <= ${thresholds.HIGH}`);
  console.log('---------------------------------------------------------');

  const failedCritical = total.CRITICAL > thresholds.CRITICAL;
  const failedHigh = total.HIGH > thresholds.HIGH;
  const hasSecrets = secretCount > 0;

  if (failedCritical || failedHigh || hasSecrets) {
    console.error('❌ SECURITY GATE FAILED');
    
    if (failedCritical) console.error(`Reason: Critical vulnerabilities (${total.CRITICAL}) exceed threshold (${thresholds.CRITICAL})`);
    if (failedHigh) console.error(`Reason: High vulnerabilities (${total.HIGH}) exceed threshold (${thresholds.HIGH})`);
    if (hasSecrets) console.error(`Reason: ${secretCount} secret(s) detected.`);

    console.error('\nFindings of Concern:');
    allIds.forEach(id => console.error(`  - ${id}`));
    console.error('---------------------------------------------------------');
    process.exit(1);
  }

  console.log('✅ SECURITY GATE PASSED');
  if (allIds.length > 0) {
    console.log('\nNote: The following findings were detected but are below the failure threshold:');
    allIds.forEach(id => console.log(`  - ${id}`));
  }
  console.log('---------------------------------------------------------');

} catch (err) {
  console.error(`Security gate execution error: ${err.message}`);
  process.exit(2);
}
