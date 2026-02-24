#!/usr/bin/env bash
# Cleanup ECS task definitions, keeping only a specified number of recent ones
set -euo pipefail

# Check for required arguments: family name and number of revisions to keep
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <task-family> <keep-count>" >&2
  exit 1
fi

family="$1"
keep_count="$2"

# Validate that keep-count is an integer
if ! [[ "$keep_count" =~ ^[0-9]+$ ]]; then
  echo "keep-count must be a non-negative integer" >&2
  exit 1
fi

# List all active task definitions for the given family, sorted by version (DESC)
mapfile -t arns < <(aws ecs list-task-definitions \
  --family-prefix "$family" \
  --sort DESC \
  --status ACTIVE \
  --query 'taskDefinitionArns' \
  --output text | tr '\t' '\n' | sed '/^$/d')

# If the number of existing ARNs is less than or equal to keep_count, no cleanup needed
if [[ ${#arns[@]} -le $keep_count ]]; then
  echo "No ECS task definitions to clean up for family $family"
  exit 0
fi

# Iterate through the ARNs starting from keep_count to the end and deregister them
for ((i=keep_count; i<${#arns[@]}; i++)); do
  echo "Deregistering old task definition: ${arns[$i]}"
  aws ecs deregister-task-definition --task-definition "${arns[$i]}" >/dev/null
done
