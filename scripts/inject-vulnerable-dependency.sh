#!/usr/bin/env bash
set -euo pipefail

# Intentionally injects a known vulnerable package version for gate validation.
npm pkg set dependencies.lodash='4.17.11'
npm install --package-lock-only

echo 'Injected vulnerable dependency lodash@4.17.11. Commit this change to verify pipeline blocks deployment.'
