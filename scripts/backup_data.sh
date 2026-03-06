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

if [ -z "${BACKUP_DEST:-}" ]; then
  echo "BACKUP_DEST is required in config" >&2
  exit 1
fi

FOUCL_DIR="${APP_ROOT%/}/foucl"

rsync -av "${APP_USER}@${VPS_HOST}:${FOUCL_DIR%/}/data/" "${BACKUP_DEST%/}/"
