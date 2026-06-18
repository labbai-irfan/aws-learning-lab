#!/usr/bin/env bash
# ApplicationStop hook — gracefully stop the running app.
# Runs from the PREVIOUS deployment's bundle, so guard everything.
set -euo pipefail

echo "[stop_server] Stopping app (if running)..."
if command -v pm2 >/dev/null 2>&1; then
  pm2 stop my-node-app || true
  pm2 delete my-node-app || true
fi
echo "[stop_server] Done."
