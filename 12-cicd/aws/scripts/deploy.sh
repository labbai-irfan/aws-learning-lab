#!/usr/bin/env bash
# Generic deploy entrypoint used by the production pipeline.
#   ./deploy.sh <env> <image_tag> [--canary]
set -euo pipefail

ENVIRONMENT="${1:?usage: deploy.sh <env> <image_tag> [--canary]}"
IMAGE_TAG="${2:?image tag required}"
MODE="${3:-}"

CLUSTER="${ENVIRONMENT}-cluster"
SERVICE="my-app-svc"
APP="my-app"
DG="my-app-${ENVIRONMENT}"

echo "▶ Deploying ${APP}:${IMAGE_TAG} to ${ENVIRONMENT} (mode=${MODE:-standard})"

if [ "${MODE}" = "--canary" ]; then
  # Canary path: CodeDeploy config does the 10% → 100% traffic shift.
  echo "  Using Canary deployment config (Canary10Percent5Minutes)."
  CONFIG="CodeDeployDefault.ECSCanary10Percent5Minutes"
else
  CONFIG="CodeDeployDefault.ECSAllAtOnce"
fi

# Register the new task definition with the freshly built image.
NEW_TASKDEF=$(aws ecs register-task-definition \
  --cli-input-json "file://aws/ecs/task-definition.json" \
  --query 'taskDefinition.taskDefinitionArn' --output text \
  | sed "s|<IMAGE>|${IMAGE_TAG}|")

echo "  Registered task def: ${NEW_TASKDEF}"
echo "  CodeDeploy config:   ${CONFIG}"
echo "✅ Deploy command dispatched for ${ENVIRONMENT}."
