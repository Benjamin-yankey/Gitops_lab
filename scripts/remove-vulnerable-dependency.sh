#!/usr/bin/env bash
set -euo pipefail

npm pkg delete dependencies.lodash
npm install --package-lock-only

echo 'Removed intentionally vulnerable dependency. Commit this change to verify pipeline passes.'
