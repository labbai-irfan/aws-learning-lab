#!/usr/bin/env bash
# ValidateService hook — confirm the app is healthy before CodeDeploy
# marks the deployment successful. Non-zero exit => deployment fails
# => CodeDeploy auto-rolls back (if rollback is enabled).
set -euo pipefail

HEALTH_URL="http://localhost:3000/health"
RETRIES=10
SLEEP=3

echo "[validate_service] Probing ${HEALTH_URL}..."
for i in $(seq 1 "${RETRIES}"); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${HEALTH_URL}" || echo 000)
  if [ "${code}" = "200" ]; then
    echo "[validate_service] Healthy (HTTP 200) on attempt ${i}."
    exit 0
  fi
  echo "  attempt ${i}/${RETRIES}: HTTP ${code} — retrying in ${SLEEP}s"
  sleep "${SLEEP}"
done

echo "[validate_service] FAILED health check — triggering rollback."
exit 1
