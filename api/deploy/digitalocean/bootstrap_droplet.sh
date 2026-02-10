#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   sudo APP_ROOT=/opt/rizzmeplease \
#        REPO_URL=https://github.com/<org>/<repo>.git \
#        REPO_BRANCH=main \
#        CERTBOT_EMAIL=you@rizzmeow.com \
#        ./bootstrap_droplet.sh

APP_ROOT="${APP_ROOT:-/opt/rizzmeplease}"
APP_USER="${APP_USER:-rizzapi}"
REPO_URL="${REPO_URL:-}"
REPO_BRANCH="${REPO_BRANCH:-main}"
DOMAIN="${DOMAIN:-rizzmeow.com}"
DOMAIN_WWW="${DOMAIN_WWW:-www.rizzmeow.com}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-admin@rizzmeow.com}"
ENABLE_CERTBOT="${ENABLE_CERTBOT:-true}"
SERVICE_NAME="rizzmeplease-api"
NGINX_SITE_PATH="/etc/nginx/sites-available/rizzmeow.com"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_TEMPLATE="$SCRIPT_DIR/rizzmeplease-api.service"
NGINX_TEMPLATE="$SCRIPT_DIR/nginx-rizzmeow.conf"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root: sudo ./bootstrap_droplet.sh"
    exit 1
fi

if [[ ! -f "$SERVICE_TEMPLATE" ]] || [[ ! -f "$NGINX_TEMPLATE" ]]; then
    echo "Missing deployment templates in $SCRIPT_DIR"
    exit 1
fi

echo "Installing system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    git \
    python3 \
    python3-venv \
    python3-pip \
    nginx \
    certbot \
    python3-certbot-nginx

if ! id -u "$APP_USER" >/dev/null 2>&1; then
    echo "Creating system user: $APP_USER"
    useradd --system --create-home --shell /bin/bash "$APP_USER"
fi

mkdir -p "$APP_ROOT"

if [[ -d "$APP_ROOT/.git" ]]; then
    chown -R "$APP_USER:$APP_USER" "$APP_ROOT"
    echo "Repository exists at $APP_ROOT. Pulling latest..."
    sudo -u "$APP_USER" git -C "$APP_ROOT" fetch origin
    sudo -u "$APP_USER" git -C "$APP_ROOT" checkout "$REPO_BRANCH"
    sudo -u "$APP_USER" git -C "$APP_ROOT" pull --ff-only origin "$REPO_BRANCH"
else
    if [[ -z "$REPO_URL" ]]; then
        echo "REPO_URL is required when cloning for the first time."
        exit 1
    fi
    echo "Cloning repository into $APP_ROOT..."
    rm -rf "$APP_ROOT"
    git clone --branch "$REPO_BRANCH" "$REPO_URL" "$APP_ROOT"
fi

API_DIR="$APP_ROOT/api"
if [[ ! -f "$API_DIR/pyproject.toml" ]]; then
    echo "Could not find $API_DIR/pyproject.toml"
    exit 1
fi

echo "Setting ownership for app directory..."
chown -R "$APP_USER:$APP_USER" "$APP_ROOT"

echo "Creating/updating virtual environment..."
sudo -u "$APP_USER" python3 -m venv "$API_DIR/.venv"
sudo -u "$APP_USER" "$API_DIR/.venv/bin/pip" install --upgrade pip
sudo -u "$APP_USER" "$API_DIR/.venv/bin/pip" install -e "$API_DIR"

if [[ ! -f "$API_DIR/.env" ]]; then
    echo "Creating .env from template..."
    cp "$API_DIR/.env.example" "$API_DIR/.env"
fi
chown "$APP_USER:$APP_USER" "$API_DIR/.env"
chmod 640 "$API_DIR/.env"

echo "Installing systemd service..."
sed \
    -e "s|__APP_USER__|$APP_USER|g" \
    -e "s|__APP_ROOT__|$APP_ROOT|g" \
    "$SERVICE_TEMPLATE" > "/etc/systemd/system/${SERVICE_NAME}.service"

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo "Installing nginx site..."
sed \
    -e "s|__DOMAIN__|$DOMAIN|g" \
    -e "s|__DOMAIN_WWW__|$DOMAIN_WWW|g" \
    "$NGINX_TEMPLATE" > "$NGINX_SITE_PATH"

ln -sf "$NGINX_SITE_PATH" /etc/nginx/sites-enabled/rizzmeow.com
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx
systemctl restart nginx

if [[ "$ENABLE_CERTBOT" == "true" ]]; then
    echo "Attempting to install TLS certificate with certbot..."
    certbot --nginx \
        --non-interactive \
        --agree-tos \
        --email "$CERTBOT_EMAIL" \
        -d "$DOMAIN" \
        -d "$DOMAIN_WWW" || {
            echo "Certbot failed. Ensure DNS points to this droplet, then re-run:"
            echo "certbot --nginx -d $DOMAIN -d $DOMAIN_WWW"
        }
fi

echo
echo "Bootstrap complete."
echo "Next required step: edit $API_DIR/.env with production values."
echo "Then restart service:"
echo "  systemctl restart $SERVICE_NAME"
echo "Check health:"
echo "  curl -fsS http://127.0.0.1:8000/health"
echo "  curl -fsS https://$DOMAIN/api/health"
