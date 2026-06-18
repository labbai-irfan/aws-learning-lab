#!/usr/bin/env bash
# AfterInstall hook — install deps / build after files are copied.
set -euo pipefail

APP_DIR="/var/www/my-node-app"
cd "${APP_DIR}"

echo "[after_install] Installing production dependencies..."
npm ci --omit=dev

echo "[after_install] Loading runtime config from SSM..."
# Example: pull env from Parameter Store into .env
aws ssm get-parameters-by-path \
  --path "/my-node-app/prod/" \
  --with-decryption \
  --query "Parameters[*].[Name,Value]" --output text \
  | sed 's#/my-node-app/prod/##' | awk '{print $1"="$2}' > .env || true

echo "[after_install] Done."
