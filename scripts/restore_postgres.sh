#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=${1:-}
DUMP_FILE=${2:-}
if [ -z "$CONFIG_FILE" ] || [ -z "$DUMP_FILE" ]; then
  echo "Usage: $0 /path/to/config.env /path/to/postgres.sql" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [ -z "${VPS_HOST:-}" ] || [ -z "${APP_USER:-}" ]; then
  echo "VPS_HOST and APP_USER are required in config" >&2
  exit 1
fi

for var_name in POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD; do
  if [ -z "${!var_name:-}" ]; then
    echo "${var_name} is required in config" >&2
    exit 1
  fi
done

if [ ! -f "$DUMP_FILE" ]; then
  echo "DUMP_FILE does not exist: ${DUMP_FILE}" >&2
  exit 1
fi

was_active=0
if ssh "${APP_USER}@${VPS_HOST}" "sudo systemctl is-active --quiet foucl"; then
  was_active=1
  echo "[restore-postgres] Stopping foucl service"
  ssh "${APP_USER}@${VPS_HOST}" "sudo systemctl stop foucl"
fi

echo "[restore-postgres] Restoring ${DUMP_FILE} into ${POSTGRES_DB}"
ssh "${APP_USER}@${VPS_HOST}" \
  POSTGRES_HOST="${POSTGRES_HOST}" \
  POSTGRES_PORT="${POSTGRES_PORT}" \
  POSTGRES_DB="${POSTGRES_DB}" \
  POSTGRES_USER="${POSTGRES_USER}" \
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  bash -lc 'export PGPASSWORD="$POSTGRES_PASSWORD"; psql --host "$POSTGRES_HOST" --port "$POSTGRES_PORT" --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -v ON_ERROR_STOP=1' \
  <"$DUMP_FILE"

if [ "$was_active" -eq 1 ]; then
  echo "[restore-postgres] Starting foucl service"
  ssh "${APP_USER}@${VPS_HOST}" "sudo systemctl start foucl"
fi

echo "[restore-postgres] Done"
