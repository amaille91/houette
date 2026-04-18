#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=${1:-}
if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: $0 /path/to/config.env" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [ -z "${BACKEND_BINARY:-}" ]; then
  echo "BACKEND_BINARY is required in config" >&2
  exit 1
fi

if [ -z "${BACKEND_MIGRATIONS_DIR:-}" ]; then
  echo "BACKEND_MIGRATIONS_DIR is required in config" >&2
  exit 1
fi

if [ -z "${BACKEND_CONFIG_FILE:-}" ]; then
  echo "BACKEND_CONFIG_FILE is required in config" >&2
  exit 1
fi

if [ ! -f "$BACKEND_BINARY" ]; then
  echo "BACKEND_BINARY does not exist: ${BACKEND_BINARY}" >&2
  exit 1
fi

if [ ! -d "$BACKEND_MIGRATIONS_DIR" ]; then
  echo "BACKEND_MIGRATIONS_DIR does not exist: ${BACKEND_MIGRATIONS_DIR}" >&2
  exit 1
fi

if [ ! -f "$BACKEND_CONFIG_FILE" ]; then
  echo "BACKEND_CONFIG_FILE does not exist: ${BACKEND_CONFIG_FILE}" >&2
  exit 1
fi

validate_backend_config() {
  local config_file="$1"

  if command -v jq >/dev/null 2>&1; then
    if ! jq -er '.auth.bootstrapAdminUsername | strings | select(length > 0)' "$config_file" >/dev/null; then
      echo "BACKEND_CONFIG_FILE is invalid: .auth.bootstrapAdminUsername must be a non-empty string (${config_file})" >&2
      exit 1
    fi

    if jq -e '
      [
        .auth.authBackend,
        .session.sessionBackend,
        .calendarBackend,
        .tripSharingBackend,
        .noteBackend,
        .checklistBackend
      ] | any(. == "postgres")
    ' "$config_file" >/dev/null; then
      if ! jq -er '.database.host | strings | select(length > 0)' "$config_file" >/dev/null; then
        echo "BACKEND_CONFIG_FILE is invalid: .database.host must be a non-empty string when any backend uses postgres (${config_file})" >&2
        exit 1
      fi
      if ! jq -er '.database.port | numbers' "$config_file" >/dev/null; then
        echo "BACKEND_CONFIG_FILE is invalid: .database.port must be numeric when any backend uses postgres (${config_file})" >&2
        exit 1
      fi
      for db_field in name user password; do
        if ! jq -er ".database.${db_field} | strings | select(length > 0)" "$config_file" >/dev/null; then
          echo "BACKEND_CONFIG_FILE is invalid: .database.${db_field} must be a non-empty string when any backend uses postgres (${config_file})" >&2
          exit 1
        fi
      done

      if [ -n "${POSTGRES_HOST:-}" ] && [ "$(jq -r '.database.host' "$config_file")" != "${POSTGRES_HOST}" ]; then
        echo "BACKEND_CONFIG_FILE is invalid: .database.host must match POSTGRES_HOST (${config_file})" >&2
        exit 1
      fi
      if [ -n "${POSTGRES_PORT:-}" ] && [ "$(jq -r '.database.port' "$config_file")" != "${POSTGRES_PORT}" ]; then
        echo "BACKEND_CONFIG_FILE is invalid: .database.port must match POSTGRES_PORT (${config_file})" >&2
        exit 1
      fi
      if [ -n "${POSTGRES_DB:-}" ] && [ "$(jq -r '.database.name' "$config_file")" != "${POSTGRES_DB}" ]; then
        echo "BACKEND_CONFIG_FILE is invalid: .database.name must match POSTGRES_DB (${config_file})" >&2
        exit 1
      fi
      if [ -n "${POSTGRES_USER:-}" ] && [ "$(jq -r '.database.user' "$config_file")" != "${POSTGRES_USER}" ]; then
        echo "BACKEND_CONFIG_FILE is invalid: .database.user must match POSTGRES_USER (${config_file})" >&2
        exit 1
      fi
      if [ -n "${POSTGRES_PASSWORD:-}" ] && [ "$(jq -r '.database.password' "$config_file")" != "${POSTGRES_PASSWORD}" ]; then
        echo "BACKEND_CONFIG_FILE is invalid: .database.password must match POSTGRES_PASSWORD (${config_file})" >&2
        exit 1
      fi
    fi
    return 0
  fi

  if ! grep -Eq '"bootstrapAdminUsername"[[:space:]]*:[[:space:]]*"[^"]+"' "$config_file"; then
    echo "BACKEND_CONFIG_FILE is invalid: .auth.bootstrapAdminUsername must be a non-empty string (${config_file})" >&2
    echo "Tip: install jq for strict JSON validation." >&2
    exit 1
  fi

  if grep -Eq '"(authBackend|sessionBackend|calendarBackend|tripSharingBackend|noteBackend|checklistBackend)"[[:space:]]*:[[:space:]]*"postgres"' "$config_file"; then
    if ! grep -Eq '"database"[[:space:]]*:[[:space:]]*\{' "$config_file"; then
      echo "BACKEND_CONFIG_FILE is invalid: .database object is required when any backend uses postgres (${config_file})" >&2
      echo "Tip: install jq for strict JSON validation." >&2
      exit 1
    fi
    if ! grep -Eq '"host"[[:space:]]*:[[:space:]]*"[^"]+"' "$config_file"; then
      echo "BACKEND_CONFIG_FILE is invalid: .database.host must be a non-empty string when any backend uses postgres (${config_file})" >&2
      echo "Tip: install jq for strict JSON validation." >&2
      exit 1
    fi
    if ! grep -Eq '"port"[[:space:]]*:[[:space:]]*[0-9]+' "$config_file"; then
      echo "BACKEND_CONFIG_FILE is invalid: .database.port must be numeric when any backend uses postgres (${config_file})" >&2
      echo "Tip: install jq for strict JSON validation." >&2
      exit 1
    fi
    for db_field in name user password; do
      if ! grep -Eq "\"${db_field}\"[[:space:]]*:[[:space:]]*\"[^\"]+\"" "$config_file"; then
        echo "BACKEND_CONFIG_FILE is invalid: .database.${db_field} must be a non-empty string when any backend uses postgres (${config_file})" >&2
        echo "Tip: install jq for strict JSON validation." >&2
        exit 1
      fi
    done
  fi
}

if [ -z "${VPS_HOST:-}" ] || [ -z "${APP_USER:-}" ] || [ -z "${APP_ROOT:-}" ]; then
  echo "VPS_HOST, APP_USER, and APP_ROOT are required in config" >&2
  exit 1
fi

echo "[deploy-back] Validating backend app-config.json"
validate_backend_config "$BACKEND_CONFIG_FILE"

FOUCL_DIR="${APP_ROOT%/}/foucl"
REMOTE_MIGRATIONS_DIR="${FOUCL_DIR%/}/db/migrations"

echo "[deploy-back] Ensuring remote directories exist"
ssh "${APP_USER}@${VPS_HOST}" "mkdir -p ${FOUCL_DIR%/}/config && mkdir -p ${REMOTE_MIGRATIONS_DIR%/}"

echo "[deploy-back] Uploading backend binary to /tmp"
scp "$BACKEND_BINARY" "${APP_USER}@${VPS_HOST}:/tmp/foucl.bin"

echo "[deploy-back] Installing backend binary"
ssh "${APP_USER}@${VPS_HOST}" "mv /tmp/foucl.bin ${FOUCL_DIR%/}/foucl && chmod +x ${FOUCL_DIR%/}/foucl"

echo "[deploy-back] Syncing Postgres migration assets"
rsync -av --delete "${BACKEND_MIGRATIONS_DIR%/}/" "${APP_USER}@${VPS_HOST}:${REMOTE_MIGRATIONS_DIR%/}/"

echo "[deploy-back] Uploading app-config.json"
scp "$BACKEND_CONFIG_FILE" "${APP_USER}@${VPS_HOST}:${FOUCL_DIR%/}/config/app-config.json"

echo "[deploy-back] Restarting service"
ssh "${APP_USER}@${VPS_HOST}" "sudo systemctl restart foucl"
