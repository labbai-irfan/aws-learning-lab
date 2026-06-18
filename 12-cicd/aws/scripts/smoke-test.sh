#!/usr/bin/env bash
# Minimal smoke test — hit critical endpoints and assert 2xx.
set -euo pipefail

BASE="${1:?usage: smoke-test.sh <base-url>}"
ENDPOINTS=("/health" "/api/version" "/")

echo "Smoke-testing ${BASE}..."
fail=0
for ep in "${ENDPOINTS[@]}"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}${ep}" || echo 000)
  if [[ "${code}" =~ ^2 ]]; then
    echo "  ✅ ${ep} → ${code}"
  else
    echo "  ❌ ${ep} → ${code}"
    fail=1
  fi
done

[ "${fail}" -eq 0 ] && echo "✅ Smoke test passed." || { echo "❌ Smoke test failed."; exit 1; }
