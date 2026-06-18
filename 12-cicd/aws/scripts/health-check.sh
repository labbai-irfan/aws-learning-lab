#!/usr/bin/env bash
# Post-deploy health verification. Exits non-zero on failure so the
# caller (pipeline) can trigger rollback.
set -euo pipefail

URL="${1:-http://localhost:3000/health}"
RETRIES="${RETRIES:-12}"
SLEEP="${SLEEP:-5}"

echo "Health-checking ${URL} (${RETRIES} attempts)..."
for i in $(seq 1 "${RETRIES}"); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${URL}" || echo 000)
  if [ "${code}" = "200" ]; then
    echo "✅ Healthy after ${i} attempt(s)."
    exit 0
  fi
  echo "  ${i}/${RETRIES}: HTTP ${code}; retry in ${SLEEP}s"
  sleep "${SLEEP}"
done

echo "❌ Health check failed."
exit 1
