#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <template-json> <output-json>" >&2
  exit 1
fi

template="$1"
out="$2"

required_vars=(
  IMAGE_URI
  TASK_FAMILY
  EXECUTION_ROLE_ARN
  TASK_ROLE_ARN
  AWS_REGION
  LOG_GROUP
  APP_VERSION
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required env var: ${var}" >&2
    exit 1
  fi
done

sed \
  -e "s|__IMAGE_URI__|${IMAGE_URI}|g" \
  -e "s|__TASK_FAMILY__|${TASK_FAMILY}|g" \
  -e "s|__EXECUTION_ROLE_ARN__|${EXECUTION_ROLE_ARN}|g" \
  -e "s|__TASK_ROLE_ARN__|${TASK_ROLE_ARN}|g" \
  -e "s|__AWS_REGION__|${AWS_REGION}|g" \
  -e "s|__LOG_GROUP__|${LOG_GROUP}|g" \
  -e "s|__APP_VERSION__|${APP_VERSION}|g" \
  "$template" > "$out"
