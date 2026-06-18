#!/usr/bin/env bash
# ApplicationStart hook — (re)start the app under PM2.
set -euo pipefail

APP_DIR="/var/www/my-node-app"
cd "${APP_DIR}"

echo "[start_server] Starting app with PM2..."
pm2 startOrReload ecosystem.config.js --env production \
  || pm2 start npm --name my-node-app -- start

pm2 save
echo "[start_server] Done."
