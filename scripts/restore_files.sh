#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=${1:-}
BACKUP_SOURCE=${2:-}
if [ -z "$CONFIG_FILE" ] || [ -z "$BACKUP_SOURCE" ]; then
  echo "Usage: $0 /path/to/config.env /path/to/files-backup" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [ -z "${VPS_HOST:-}" ] || [ -z "${APP_USER:-}" ] || [ -z "${APP_ROOT:-}" ]; then
  echo "VPS_HOST, APP_USER, and APP_ROOT are required in config" >&2
  exit 1
fi

if [ ! -d "$BACKUP_SOURCE" ]; then
  echo "Backup source does not exist: ${BACKUP_SOURCE}" >&2
  exit 1
fi

foucl_dir="${APP_ROOT%/}/foucl"
was_active=0

if ssh "${APP_USER}@${VPS_HOST}" "sudo systemctl is-active --quiet foucl"; then
  was_active=1
  echo "[restore-files] Stopping foucl service"
  ssh "${APP_USER}@${VPS_HOST}" "sudo systemctl stop foucl"
fi

echo "[restore-files] Restoring ${BACKUP_SOURCE} to ${foucl_dir}/data"
ssh "${APP_USER}@${VPS_HOST}" "mkdir -p ${foucl_dir%/}/data"
rsync -av --delete "${BACKUP_SOURCE%/}/" "${APP_USER}@${VPS_HOST}:${foucl_dir%/}/data/"

if [ "$was_active" -eq 1 ]; then
  echo "[restore-files] Starting foucl service"
  ssh "${APP_USER}@${VPS_HOST}" "sudo systemctl start foucl"
fi

echo "[restore-files] Done"
