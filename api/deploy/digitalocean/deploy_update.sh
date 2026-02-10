#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   sudo APP_ROOT=/opt/rizzmeplease REPO_BRANCH=main ./deploy_update.sh

APP_ROOT="${APP_ROOT:-/opt/rizzmeplease}"
APP_USER="${APP_USER:-rizzapi}"
REPO_BRANCH="${REPO_BRANCH:-main}"
SERVICE_NAME="${SERVICE_NAME:-rizzmeplease-api}"
API_DIR="$APP_ROOT/api"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root: sudo ./deploy_update.sh"
    exit 1
fi

if [[ ! -d "$APP_ROOT/.git" ]]; then
    echo "Repository not found at $APP_ROOT"
    exit 1
fi

echo "Updating repository..."
sudo -u "$APP_USER" git -C "$APP_ROOT" fetch origin
sudo -u "$APP_USER" git -C "$APP_ROOT" checkout "$REPO_BRANCH"
sudo -u "$APP_USER" git -C "$APP_ROOT" pull --ff-only origin "$REPO_BRANCH"

echo "Installing Python dependencies..."
if [[ ! -x "$API_DIR/.venv/bin/pip" ]]; then
    echo "Virtual environment missing at $API_DIR/.venv"
    echo "Run bootstrap_droplet.sh first."
    exit 1
fi
sudo -u "$APP_USER" "$API_DIR/.venv/bin/pip" install -e "$API_DIR"

echo "Restarting service..."
systemctl restart "$SERVICE_NAME"
systemctl --no-pager --full status "$SERVICE_NAME" | sed -n '1,20p'

echo "Health check:"
curl -fsS http://127.0.0.1:8000/health
echo
echo "Deploy update complete."
