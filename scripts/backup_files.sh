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

FILES_BACKUP_DEST="${FILES_BACKUP_DEST:-${BACKUP_DEST:-}}"
if [ -z "${FILES_BACKUP_DEST:-}" ]; then
  echo "FILES_BACKUP_DEST is required in config" >&2
  exit 1
fi

timestamp=$(date -u +"%Y%m%dT%H%M%SZ")
backup_dir="${FILES_BACKUP_DEST%/}/${timestamp}"
foucl_dir="${APP_ROOT%/}/foucl"

mkdir -p "$backup_dir"

echo "[backup-files] Saving ${foucl_dir}/data to ${backup_dir}"
rsync -av --delete "${APP_USER}@${VPS_HOST}:${foucl_dir%/}/data/" "${backup_dir%/}/"

echo "[backup-files] Done: ${backup_dir}"
