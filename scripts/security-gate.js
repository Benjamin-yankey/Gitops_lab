const fs = require('fs');

const files = {
  sca: process.env.SCA_REPORT || 'reports/sca/dependency-check-report.json',
  image: process.env.IMAGE_REPORT || 'reports/image/trivy-image.json',
  secret: process.env.SECRET_REPORT || 'reports/secret/gitleaks-report.json'
};

const sevOrder = ['CRITICAL', 'HIGH'];

function safeReadJson(path) {
  if (!fs.existsSync(path)) {
    throw new Error(`Required report not found: ${path}`);
  }
  return JSON.parse(fs.readFileSync(path, 'utf8'));
}

function countDependencyCheck(report) {
  const counts = { CRITICAL: 0, HIGH: 0 };
  const dependencies = report.dependencies || [];
  for (const dep of dependencies) {
    for (const vuln of dep.vulnerabilities || []) {
      const sev = String(vuln.severity || '').toUpperCase();
      if (counts[sev] !== undefined) counts[sev] += 1;
    }
  }
  return counts;
}

function countTrivy(report) {
  const counts = { CRITICAL: 0, HIGH: 0 };
  for (const result of report.Results || []) {
    for (const vuln of result.Vulnerabilities || []) {
      const sev = String(vuln.Severity || '').toUpperCase();
      if (counts[sev] !== undefined) counts[sev] += 1;
    }
  }
  return counts;
}

function countGitleaks(report) {
  return Array.isArray(report) ? report.length : 0;
}

function mergeCounts(a, b) {
  return {
    CRITICAL: (a.CRITICAL || 0) + (b.CRITICAL || 0),
    HIGH: (a.HIGH || 0) + (b.HIGH || 0)
  };
}

try {
  const sca = safeReadJson(files.sca);
  const image = safeReadJson(files.image);
  const secret = safeReadJson(files.secret);

  const scaCounts = countDependencyCheck(sca);
  const imageCounts = countTrivy(image);
  const total = mergeCounts(scaCounts, imageCounts);
  const secretCount = countGitleaks(secret);

  console.log(`SCA vulnerabilities: critical=${scaCounts.CRITICAL}, high=${scaCounts.HIGH}`);
  console.log(`Image vulnerabilities: critical=${imageCounts.CRITICAL}, high=${imageCounts.HIGH}`);
  console.log(`Secrets detected: ${secretCount}`);

  const hasBlockedVulns = sevOrder.some((sev) => total[sev] > 0);
  const hasSecrets = secretCount > 0;

  if (hasBlockedVulns || hasSecrets) {
    console.error('Security gate failed. Critical/High vulnerabilities or secrets were detected.');
    process.exit(1);
  }

  console.log('Security gate passed. No Critical/High vulnerabilities and no secrets detected.');
} catch (err) {
  console.error(`Security gate execution error: ${err.message}`);
  process.exit(2);
}
