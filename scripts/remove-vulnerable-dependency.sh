#!/usr/bin/env bash
# Script to revert the vulnerability injection and restore project security
set -euo pipefail

# Remove the vulnerable lodash dependency from package.json
npm pkg delete dependencies.lodash
# Update package-lock.json to reflect the removal
npm install --package-lock-only

echo 'Removed intentionally vulnerable dependency. Commit this change to verify pipeline passes.'
