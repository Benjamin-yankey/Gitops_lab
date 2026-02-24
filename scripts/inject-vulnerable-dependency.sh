#!/usr/bin/env bash
# Script to simulate a security vulnerability by injecting an old version of lodash
set -euo pipefail

# Intentionally injects a known vulnerable package version for gate validation.
# This is used to test if the security pipeline correctly blocks insecure dependencies.
npm pkg set dependencies.lodash='4.17.11'
# Update package-lock.json without installing the package
npm install --package-lock-only

echo 'Injected vulnerable dependency lodash@4.17.11. Commit this change to verify pipeline blocks deployment.'
