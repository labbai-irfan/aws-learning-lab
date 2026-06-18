#!/usr/bin/env bash
# BeforeInstall hook — prepare the host before files are copied.
set -euo pipefail

APP_DIR="/var/www/my-node-app"

echo "[before_install] Ensuring Node.js + PM2 are installed..."
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
  yum install -y nodejs
fi
command -v pm2 >/dev/null 2>&1 || npm install -g pm2

echo "[before_install] Cleaning previous release..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}"

echo "[before_install] Done."
