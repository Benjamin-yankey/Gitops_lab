# Secure CI/CD Pipeline - ECS + Security Gates

This implementation hardens the existing Node.js pipeline with SAST, SCA, container scanning, SBOM, secret scanning, ECR image versioning, and ECS rolling deployment.

## Deliverables Included

- `Jenkinsfile`: secure CI/CD workflow with quality gates and ECS deployment
- `ecs/taskdef.template.json`: ECS task definition template
- `ecs/taskdef.rendered.example.json`: rendered task definition example revision payload
- `ecs/ecr-lifecycle-policy.json`: ECR image cleanup policy
- `scripts/security-gate.js`: blocks on Critical/High vulnerabilities or secrets
- `reports/`: archived scan/deploy artifacts (populated by pipeline run)

## Security Controls Implemented

- SAST: SonarQube analysis + `waitForQualityGate` pipeline block
- SCA: OWASP Dependency-Check JSON/HTML report
- Image scanning: Trivy JSON report for container image
- Secret scanning: Gitleaks JSON report
- SBOM: Syft CycloneDX JSON output
- Gate policy: fail build if any High/Critical vulnerabilities or any secrets are detected

## Required Jenkins/Runtime Prereqs

- Jenkins plugins: SonarQube Scanner, JUnit, Pipeline utility basics
- Jenkins agent has: `docker`, `aws`, `node`, and permission to run docker socket scans
- SonarQube server configured in Jenkins as `sonarqube`
- AWS credentials available to Jenkins with ECR/ECS/IAM permissions

## ECS Deployment Flow

1. Build versioned image tags (`build-<build>-<sha>`, `sha-<sha>`, `latest`)
2. Push tags to ECR
3. Render task definition (`reports/deploy/taskdef.rendered.json`) with new image URI
4. Register task definition revision
5. Update ECS service with new revision (`aws ecs update-service --force-new-deployment`)
6. Wait for stable service and archive deployment evidence in `reports/deploy/`

## CloudWatch and Monitoring

- ECS task definition uses `awslogs` log driver and `awslogs-group` provided via parameter.
- Existing monitoring alarms from Project-Monitoring can continue targeting ECS-backed metrics/log groups.

## Validation Procedure (Required Evidence)

### 1. Gate Fails on Vulnerability Injection

Run locally, commit, then trigger pipeline:

```bash
scripts/inject-vulnerable-dependency.sh
```

Expected: SCA report contains High/Critical findings and `Security Gate` stage fails before ECR/ECS deploy.

Save evidence to:

- `reports/sca/dependency-check-report.json`
- `reports/sca/dependency-check-report.html`
- Jenkins screenshot/log showing gate failure

### 2. Gate Passes After Fix

```bash
scripts/remove-vulnerable-dependency.sh
```

Expected: Security gate passes and deployment stages complete.

Save evidence to:

- `reports/image/trivy-image.json`
- `reports/secret/gitleaks-report.json`
- `reports/sbom/sbom-cyclonedx.json`
- `reports/deploy/ecs-update-service.json`
- `reports/deploy/ecs-service-status.json`

## Notes

- Rolling deployment is implemented in this pipeline (`DEPLOYMENT_STRATEGY=rolling`).
- ECR lifecycle policy is applied automatically when enabled.
- Old ECS task definition revisions are cleaned up after successful deployment.
