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

for var_name in POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD POSTGRES_BACKUP_DEST; do
  if [ -z "${!var_name:-}" ]; then
    echo "${var_name} is required in config" >&2
    exit 1
  fi
done

timestamp=$(date -u +"%Y%m%dT%H%M%SZ")
mkdir -p "${POSTGRES_BACKUP_DEST%/}"
dump_file="${POSTGRES_BACKUP_DEST%/}/${POSTGRES_DB}-${timestamp}.sql"

echo "[backup-postgres] Saving ${POSTGRES_DB} to ${dump_file}"
ssh "${APP_USER}@${VPS_HOST}" \
  POSTGRES_HOST="${POSTGRES_HOST}" \
  POSTGRES_PORT="${POSTGRES_PORT}" \
  POSTGRES_DB="${POSTGRES_DB}" \
  POSTGRES_USER="${POSTGRES_USER}" \
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  'bash -s' <<'REMOTE' >"$dump_file"
set -euo pipefail
export PGPASSWORD="${POSTGRES_PASSWORD}"
pg_dump \
  --host "${POSTGRES_HOST}" \
  --port "${POSTGRES_PORT}" \
  --username "${POSTGRES_USER}" \
  --dbname "${POSTGRES_DB}" \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  --format=plain
REMOTE

echo "[backup-postgres] Done: ${dump_file}"
