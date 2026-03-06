#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=${1:-}
if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: $0 /path/to/config.env" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [ -z "${VPS_HOST:-}" ] || [ -z "${APP_USER:-}" ]; then
  echo "VPS_HOST and APP_USER are required in config" >&2
  exit 1
fi

ssh "${APP_USER}@${VPS_HOST}" bash -s <<'REMOTE'
set -euo pipefail

sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443

if ! sudo ufw status | grep -q "Status: active"; then
  sudo ufw --force enable
fi

sudo ufw status verbose
REMOTE
