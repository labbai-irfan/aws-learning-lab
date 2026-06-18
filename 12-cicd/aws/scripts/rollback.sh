#!/usr/bin/env bash
# Roll back to the previous stable ECS task definition revision.
set -euo pipefail

ENVIRONMENT="${1:?usage: rollback.sh <env>}"
CLUSTER="${ENVIRONMENT}-cluster"
SERVICE="my-app-svc"
FAMILY="my-app"

echo "⏪ Rolling back ${SERVICE} in ${CLUSTER}..."

# Find the second-newest ACTIVE task def revision (previous stable).
PREV=$(aws ecs list-task-definitions \
  --family-prefix "${FAMILY}" \
  --status ACTIVE --sort DESC \
  --query 'taskDefinitionArns[1]' --output text)

if [ "${PREV}" = "None" ] || [ -z "${PREV}" ]; then
  echo "❌ No previous revision found to roll back to."
  exit 1
fi

aws ecs update-service \
  --cluster "${CLUSTER}" \
  --service "${SERVICE}" \
  --task-definition "${PREV}" \
  --force-new-deployment >/dev/null

echo "✅ Rolled back to ${PREV}."
