#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=${1:-}
if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: $0 /path/to/config.env" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [ -z "${VPS_HOST:-}" ] || [ -z "${ROOT_USER:-}" ]; then
  echo "VPS_HOST and ROOT_USER are required in config" >&2
  exit 1
fi

for var_name in POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD; do
  if [ -z "${!var_name:-}" ]; then
    echo "${var_name} is required in config" >&2
    exit 1
  fi
done

echo "[deploy-postgres] Connecting to ${ROOT_USER}@${VPS_HOST}"

ssh "${ROOT_USER}@${VPS_HOST}" \
  POSTGRES_HOST="${POSTGRES_HOST}" \
  POSTGRES_PORT="${POSTGRES_PORT}" \
  POSTGRES_DB="${POSTGRES_DB}" \
  POSTGRES_USER="${POSTGRES_USER}" \
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  bash -s <<'REMOTE'
set -euo pipefail

sql_escape_literal() {
  printf "%s" "$1" | sed "s/'/''/g"
}

sql_escape_ident() {
  printf "%s" "$1" | sed 's/"/""/g'
}

role_exists() {
  sudo -u postgres psql --dbname postgres -tAc \
    "SELECT 1 FROM pg_roles WHERE rolname = '$(sql_escape_literal "$POSTGRES_USER")'" | grep -q 1
}

database_exists() {
  sudo -u postgres psql --dbname postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname = '$(sql_escape_literal "$POSTGRES_DB")'" | grep -q 1
}

echo "[deploy-postgres] Checking PostgreSQL packages"
if command -v psql >/dev/null 2>&1 && sudo systemctl cat postgresql >/dev/null 2>&1; then
  echo "[deploy-postgres] PostgreSQL already installed"
else
  echo "[deploy-postgres] Installing PostgreSQL server and client packages"
  sudo apt-get update -y
  sudo apt-get install -y postgresql postgresql-client postgresql-contrib
fi

echo "[deploy-postgres] Ensuring postgresql.service is enabled"
if ! sudo systemctl is-enabled --quiet postgresql; then
  sudo systemctl enable postgresql
fi

echo "[deploy-postgres] Ensuring postgresql.service is running"
if ! sudo systemctl is-active --quiet postgresql; then
  sudo systemctl start postgresql
fi

if role_exists; then
  echo "[deploy-postgres] Role ${POSTGRES_USER} already exists"
else
  echo "[deploy-postgres] Creating role ${POSTGRES_USER}"
  sudo -u postgres psql --dbname postgres -v ON_ERROR_STOP=1 -c \
    "CREATE ROLE \"$(sql_escape_ident "$POSTGRES_USER")\" WITH LOGIN PASSWORD '$(sql_escape_literal "$POSTGRES_PASSWORD")'"
fi

echo "[deploy-postgres] Syncing role password"
sudo -u postgres psql --dbname postgres -v ON_ERROR_STOP=1 -c \
  "ALTER ROLE \"$(sql_escape_ident "$POSTGRES_USER")\" WITH LOGIN PASSWORD '$(sql_escape_literal "$POSTGRES_PASSWORD")'"

if database_exists; then
  echo "[deploy-postgres] Database ${POSTGRES_DB} already exists"
else
  echo "[deploy-postgres] Creating database ${POSTGRES_DB}"
  sudo -u postgres createdb --owner "${POSTGRES_USER}" "${POSTGRES_DB}"
fi

current_owner=$(sudo -u postgres psql --dbname postgres -tAc \
  "SELECT pg_catalog.pg_get_userbyid(datdba) FROM pg_database WHERE datname = '$(sql_escape_literal "$POSTGRES_DB")'" | xargs)
if [ "$current_owner" != "$POSTGRES_USER" ]; then
  echo "[deploy-postgres] Reassigning database owner to ${POSTGRES_USER}"
  sudo -u postgres psql --dbname postgres -v ON_ERROR_STOP=1 -c \
    "ALTER DATABASE \"$(sql_escape_ident "$POSTGRES_DB")\" OWNER TO \"$(sql_escape_ident "$POSTGRES_USER")\""
fi

echo "[deploy-postgres] Verifying application connectivity"
export PGPASSWORD="${POSTGRES_PASSWORD}"
psql \
  --host "${POSTGRES_HOST}" \
  --port "${POSTGRES_PORT}" \
  --username "${POSTGRES_USER}" \
  --dbname "${POSTGRES_DB}" \
  -v ON_ERROR_STOP=1 \
  -tAc "SELECT 1" >/dev/null

echo "[deploy-postgres] Done"
REMOTE
