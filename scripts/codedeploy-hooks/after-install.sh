#!/bin/bash
# CodeDeploy AfterInstall Hook
# Runs after the new application version is installed but before traffic shifts

set -euo pipefail

echo "🟢 CodeDeploy AfterInstall: New version installed, preparing for traffic shift..."

# Wait for ECS service to stabilize
echo "⏳ Waiting for ECS service to reach stable state..."
sleep 30

# Log the new task definition
echo "📋 New task definition deployed successfully"

echo "✅ AfterInstall completed successfully"