#!/bin/bash
# CodeDeploy ApplicationStart Hook
# Runs when the new application version starts receiving traffic

set -euo pipefail

echo "🚀 CodeDeploy ApplicationStart: New version is now receiving traffic..."

# Log traffic shift
echo "📈 Traffic is being shifted to the new version"
echo "🔄 Blue-green deployment in progress..."

echo "✅ ApplicationStart completed successfully"