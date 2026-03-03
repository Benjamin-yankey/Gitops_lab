#!/usr/bin/env bash

# ECS Task Definition Template Renderer
#
# This script processes an ECS task definition template by replacing placeholder
# variables with actual values from environment variables. It's a critical part
# of the CI/CD pipeline that enables dynamic configuration of container deployments.
#
# Purpose:
# - Convert template files with __PLACEHOLDER__ variables into valid ECS task definitions
# - Inject build-specific values (image URIs, versions, ARNs) at deployment time
# - Validate that all required configuration is present before deployment
# - Generate deployment-ready JSON files for AWS ECS
#
# Usage: ./render-ecs-taskdef.sh <template-file> <output-file>
# Example: ./render-ecs-taskdef.sh taskdef.template.json taskdef.rendered.json
#
# The script uses sed for string replacement, which is fast and reliable for
# simple placeholder substitution in JSON templates.

# Enable strict error handling
# -e: Exit immediately if any command fails
# -u: Treat unset variables as errors
# -o pipefail: Fail if any command in a pipeline fails
set -euo pipefail

# Validate command line arguments
# The script requires exactly two arguments: input template and output file
if [[ $# -ne 2 ]]; then
  echo "ERROR: Invalid number of arguments" >&2
  echo "Usage: $0 <template-json> <output-json>" >&2
  echo "" >&2
  echo "Example:" >&2
  echo "  $0 ecs/taskdef.template.json reports/deploy/taskdef.rendered.json" >&2
  exit 1
fi

# Assign command line arguments to descriptive variables
template="$1"  # Input template file path
out="$2"       # Output rendered file path

# Validate that the template file exists
if [[ ! -f "$template" ]]; then
  echo "ERROR: Template file not found: $template" >&2
  exit 1
fi

# Validate that the output directory exists
output_dir=$(dirname "$out")
if [[ ! -d "$output_dir" ]]; then
  echo "ERROR: Output directory does not exist: $output_dir" >&2
  echo "Create the directory first: mkdir -p $output_dir" >&2
  exit 1
fi

# Define all required environment variables for ECS task definition
# These variables must be set by the CI/CD pipeline before calling this script
required_vars=(
  IMAGE_URI           # Full ECR image URI (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/app:latest)
  TASK_FAMILY         # ECS task definition family name (e.g., cicd-node-app)
  EXECUTION_ROLE_ARN  # IAM role ARN for ECS task execution (pulling images, logging)
  TASK_ROLE_ARN       # IAM role ARN for the application container (AWS API access)
  AWS_REGION          # AWS region where the task will run (e.g., us-east-1)
  LOG_GROUP           # CloudWatch log group name (e.g., /ecs/cicd-node-app)
  APP_VERSION         # Application version for container environment variable
)

echo "🔧 Rendering ECS task definition template..."
echo "📄 Template: $template"
echo "📝 Output: $out"
echo ""

# Validate that all required environment variables are set and non-empty
# This prevents deployment of incomplete or invalid task definitions
echo "✅ Validating required environment variables:"
missing_vars=()
for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "  ❌ $var: NOT SET"
    missing_vars+=("$var")
  else
    # Show first 50 characters of the value for verification (truncate long ARNs)
    value="${!var}"
    display_value="${value:0:50}"
    if [[ ${#value} -gt 50 ]]; then
      display_value="${display_value}..."
    fi
    echo "  ✅ $var: $display_value"
  fi
done

# Exit if any required variables are missing
if [[ ${#missing_vars[@]} -gt 0 ]]; then
  echo "" >&2
  echo "ERROR: Missing required environment variables:" >&2
  for var in "${missing_vars[@]}"; do
    echo "  - $var" >&2
  done
  echo "" >&2
  echo "These variables must be set by the CI/CD pipeline before rendering." >&2
  exit 1
fi

echo ""
echo "🔄 Performing template substitution..."

# Perform string replacement using sed to generate the final JSON file
# Each -e flag specifies a substitution rule: s|placeholder|value|g
# The 'g' flag ensures all occurrences of each placeholder are replaced
# Using '|' as delimiter instead of '/' to avoid conflicts with ARN paths
sed \
  -e "s|__IMAGE_URI__|${IMAGE_URI}|g" \
  -e "s|__TASK_FAMILY__|${TASK_FAMILY}|g" \
  -e "s|__EXECUTION_ROLE_ARN__|${EXECUTION_ROLE_ARN}|g" \
  -e "s|__TASK_ROLE_ARN__|${TASK_ROLE_ARN}|g" \
  -e "s|__AWS_REGION__|${AWS_REGION}|g" \
  -e "s|__LOG_GROUP__|${LOG_GROUP}|g" \
  -e "s|__APP_VERSION__|${APP_VERSION}|g" \
  "$template" > "$out"

# Verify that the output file was created successfully
if [[ ! -f "$out" ]]; then
  echo "ERROR: Failed to create output file: $out" >&2
  exit 1
fi

# Validate that the output is valid JSON
if ! node -e "JSON.parse(require('fs').readFileSync('$out', 'utf8'))" 2>/dev/null; then
  echo "ERROR: Generated file is not valid JSON: $out" >&2
  echo "This usually indicates a problem with the template or variable values." >&2
  exit 1
fi

# Get file size for verification
file_size=$(wc -c < "$out")

echo "✅ Task definition rendered successfully!"
echo "📊 Output file size: $file_size bytes"
echo "🎯 Ready for ECS deployment"
echo ""
echo "Next steps:"
echo "  1. Register task definition: aws ecs register-task-definition --cli-input-json file://$out"
echo "  2. Update ECS service to use new task definition"
echo "  3. Wait for service to reach stable state"
