#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <task-family> <keep-count>" >&2
  exit 1
fi

family="$1"
keep_count="$2"

if ! [[ "$keep_count" =~ ^[0-9]+$ ]]; then
  echo "keep-count must be a non-negative integer" >&2
  exit 1
fi

mapfile -t arns < <(aws ecs list-task-definitions \
  --family-prefix "$family" \
  --sort DESC \
  --status ACTIVE \
  --query 'taskDefinitionArns' \
  --output text | tr '\t' '\n' | sed '/^$/d')

if [[ ${#arns[@]} -le $keep_count ]]; then
  echo "No ECS task definitions to clean up for family $family"
  exit 0
fi

for ((i=keep_count; i<${#arns[@]}; i++)); do
  echo "Deregistering old task definition: ${arns[$i]}"
  aws ecs deregister-task-definition --task-definition "${arns[$i]}" >/dev/null
done
