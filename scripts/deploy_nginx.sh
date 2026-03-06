#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=${1:-}
if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: $0 /path/to/config.env" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [ -z "${VPS_HOST:-}" ] || [ -z "${APP_USER:-}" ] || [ -z "${APP_ROOT:-}" ] || [ -z "${DOMAIN:-}" ]; then
  echo "VPS_HOST, APP_USER, APP_ROOT, and DOMAIN are required in config" >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RENDER_DIR=$(mktemp -d)

# Determine whether cert exists on remote (needs sudo to read /etc/letsencrypt)
CERT_EXISTS=$(ssh "${APP_USER}@${VPS_HOST}" "sudo -n test -f /etc/letsencrypt/live/${DOMAIN}/fullchain.pem && echo yes || echo no")

echo "[deploy-nginx] Certificate exists: ${CERT_EXISTS}"

if [ "$CERT_EXISTS" = "yes" ]; then
  TEMPLATE="$SCRIPT_DIR/../deploy/nginx/site.https.conf.template"
  echo "[deploy-nginx] Using HTTPS template"
else
  TEMPLATE="$SCRIPT_DIR/../deploy/nginx/site.http.conf.template"
  echo "[deploy-nginx] Using HTTP template (no cert yet)"
fi

export APP_ROOT DOMAIN

echo "[deploy-nginx] Rendering templates to ${RENDER_DIR}"
envsubst '$APP_ROOT $DOMAIN' < "$TEMPLATE" > "$RENDER_DIR/nginx.conf"

echo "[deploy-nginx] Uploading nginx.conf to ${APP_USER}@${VPS_HOST}"
scp "$RENDER_DIR/nginx.conf" "${APP_USER}@${VPS_HOST}:/tmp/nginx.conf"

echo "[deploy-nginx] Applying config and reloading nginx"
ssh "${APP_USER}@${VPS_HOST}" bash -s <<'REMOTE'
set -euo pipefail

sudo mv /tmp/nginx.conf /etc/nginx/sites-available/favs.new

if [ -f /etc/nginx/sites-available/favs ]; then
  sudo cp /etc/nginx/sites-available/favs /etc/nginx/sites-available/favs.bak
fi

# Ensure sites-enabled link exists and points to the new config for testing
if [ -L /etc/nginx/sites-enabled/favs ]; then
  sudo ln -sf /etc/nginx/sites-available/favs.new /etc/nginx/sites-enabled/favs
elif [ ! -e /etc/nginx/sites-enabled/favs ]; then
  sudo ln -s /etc/nginx/sites-available/favs.new /etc/nginx/sites-enabled/favs
else
  sudo rm -f /etc/nginx/sites-enabled/favs
  sudo ln -s /etc/nginx/sites-available/favs.new /etc/nginx/sites-enabled/favs
fi

if sudo nginx -t; then
  sudo mv /etc/nginx/sites-available/favs.new /etc/nginx/sites-available/favs
  sudo ln -sf /etc/nginx/sites-available/favs /etc/nginx/sites-enabled/favs
  sudo systemctl reload nginx
else
  echo "[deploy-nginx] nginx -t failed, restoring previous config" >&2
  if [ -f /etc/nginx/sites-available/favs.bak ]; then
    sudo mv /etc/nginx/sites-available/favs.bak /etc/nginx/sites-available/favs
    sudo ln -sf /etc/nginx/sites-available/favs /etc/nginx/sites-enabled/favs
  fi
  exit 1
fi
REMOTE

echo "[deploy-nginx] Cleaning up"
rm -rf "$RENDER_DIR"

echo "[deploy-nginx] Done"
