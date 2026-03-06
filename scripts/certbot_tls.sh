#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=${1:-}
if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: $0 /path/to/config.env" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [ -z "${VPS_HOST:-}" ] || [ -z "${APP_USER:-}" ] || [ -z "${DOMAIN:-}" ] || [ -z "${ACME_EMAIL:-}" ]; then
  echo "VPS_HOST, APP_USER, DOMAIN, and ACME_EMAIL are required in config" >&2
  exit 1
fi

echo "[certbot] Connecting to ${APP_USER}@${VPS_HOST}"

ssh "${APP_USER}@${VPS_HOST}" DOMAIN="${DOMAIN}" ACME_EMAIL="${ACME_EMAIL}" bash -s <<'REMOTE'
set -euo pipefail

echo "[certbot] Checking existing certificate"
if sudo certbot certificates -d "${DOMAIN}" 2>/dev/null | grep -q "Certificate Name:"; then
  echo "[certbot] Existing certificate found for ${DOMAIN} via certbot"
  echo "[certbot] Skipping issuance"
  exit 0
fi

# Fallback: check live directory variants
if ls -d "/etc/letsencrypt/live/${DOMAIN}"* >/dev/null 2>&1; then
  echo "[certbot] Existing certificate directory found for ${DOMAIN}"
  echo "[certbot] Skipping issuance"
  exit 0
fi

echo "[certbot] No existing certificate for ${DOMAIN}"

echo "[certbot] Requesting certificate for ${DOMAIN}"
sudo certbot --nginx -d "${DOMAIN}" --email "${ACME_EMAIL}" --agree-tos --redirect --non-interactive

echo "[certbot] Done"
REMOTE
