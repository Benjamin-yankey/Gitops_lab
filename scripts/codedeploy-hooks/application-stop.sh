#!/bin/bash
# CodeDeploy ApplicationStop Hook
# Runs when the old application version stops receiving traffic

set -euo pipefail

echo "🛑 CodeDeploy ApplicationStop: Old version is being stopped..."

# Graceful shutdown procedures could go here
echo "🔄 Gracefully stopping old application version"

echo "✅ ApplicationStop completed successfully"