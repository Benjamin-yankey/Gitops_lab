#!/bin/bash
# CodeDeploy BeforeInstall Hook
# Runs before the new application version is installed

set -euo pipefail

echo "🔵 CodeDeploy BeforeInstall: Preparing for blue-green deployment..."

# Log deployment metadata
echo "Deployment ID: ${DEPLOYMENT_ID:-unknown}"
echo "Application Name: ${APPLICATION_NAME:-unknown}"
echo "Deployment Group: ${DEPLOYMENT_GROUP_NAME:-unknown}"

# Ensure CloudWatch agent is running for monitoring
if command -v amazon-cloudwatch-agent-ctl >/dev/null 2>&1; then
    echo "📊 Starting CloudWatch agent..."
    amazon-cloudwatch-agent-ctl -a start || true
fi

echo "✅ BeforeInstall completed successfully"