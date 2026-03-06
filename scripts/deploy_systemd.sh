#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=${1:-}
if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: $0 /path/to/config.env" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [ -z "${VPS_HOST:-}" ] || [ -z "${APP_USER:-}" ] || [ -z "${APP_ROOT:-}" ]; then
  echo "VPS_HOST, APP_USER, and APP_ROOT are required in config" >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RENDER_DIR=$(mktemp -d)

"$SCRIPT_DIR/render_templates.sh" "$CONFIG_FILE" "$RENDER_DIR"

scp "$RENDER_DIR/foucl.service" "${APP_USER}@${VPS_HOST}:/tmp/foucl.service"
ssh "${APP_USER}@${VPS_HOST}" "sudo mv /tmp/foucl.service /etc/systemd/system/foucl.service && sudo systemctl daemon-reload && sudo systemctl enable foucl"

rm -rf "$RENDER_DIR"
