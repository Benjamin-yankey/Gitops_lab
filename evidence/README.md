# Evidence Pack

Populate this folder after running Jenkins pipeline:

- Failing gate evidence (injected vulnerable dependency)
- Passing gate evidence (fixed dependency)
- ECS service update evidence
- Security report files and SBOM

Recommended captured artifacts:

1. Jenkins stage screenshots for failed and successful builds
2. `reports/sca/dependency-check-report.html`
3. `reports/image/trivy-image.json`
4. `reports/secret/gitleaks-report.json`
5. `reports/sbom/sbom-cyclonedx.json`
6. `reports/deploy/taskdef.rendered.json`
7. `reports/deploy/ecs-update-service.json`
8. `reports/deploy/ecs-service-status.json`
