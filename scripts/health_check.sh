#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=${1:-}
if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: $0 /path/to/config.env" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [ -z "${VPS_HOST:-}" ] || [ -z "${APP_USER:-}" ] || [ -z "${DOMAIN:-}" ]; then
  echo "VPS_HOST, APP_USER, and DOMAIN are required in config" >&2
  exit 1
fi

echo "[health] Checking systemd service"
if ! ssh "${APP_USER}@${VPS_HOST}" "sudo systemctl is-active --quiet foucl"; then
  echo "[health] foucl service is not active" >&2
  ssh "${APP_USER}@${VPS_HOST}" "sudo systemctl status foucl -l --no-pager" || true
  exit 3
fi

echo "[health] Checking frontend"
front_status=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/" || true)
if [ "$front_status" != "200" ]; then
  echo "[health] Frontend check failed: HTTP ${front_status}" >&2
  echo "[health] Frontend response headers:" >&2
  curl -s -I "https://${DOMAIN}/" >&2 || true
  exit 7
fi

echo "[health] Checking API (expects 200 or 401)"
api_status=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/api/note" || true)
if [ "$api_status" != "200" ] && [ "$api_status" != "401" ]; then
  echo "[health] API check failed: HTTP ${api_status}" >&2
  echo "[health] API response headers:" >&2
  curl -s -I "https://${DOMAIN}/api/note" >&2 || true
  exit 8
fi

echo "[health] OK"
