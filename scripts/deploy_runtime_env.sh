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

if [[ "${APP_ROOT}" != /* ]]; then
  echo "APP_ROOT must be an absolute path (got: ${APP_ROOT})" >&2
  exit 1
fi

if [ -z "${FOUCL_SESSION_SECRET:-}" ]; then
  echo "FOUCL_SESSION_SECRET is required in config" >&2
  exit 1
fi

FOUCL_CONFIG_FILE_DEFAULT="${APP_ROOT%/}/foucl/config/app-config.json"
FOUCL_CONFIG_FILE="${FOUCL_CONFIG_FILE:-$FOUCL_CONFIG_FILE_DEFAULT}"
FOUCL_SESSION_COOKIE_SECURE="${FOUCL_SESSION_COOKIE_SECURE:-true}"
RUNTIME_ENV_REMOTE="${RUNTIME_ENV_REMOTE:-${APP_ROOT%/}/foucl/config/runtime.env}"

TMP_ENV=$(mktemp)
cat > "$TMP_ENV" <<EOF_ENV
FOUCL_SESSION_SECRET=${FOUCL_SESSION_SECRET}
FOUCL_CONFIG_FILE=${FOUCL_CONFIG_FILE}
FOUCL_SESSION_COOKIE_SECURE=${FOUCL_SESSION_COOKIE_SECURE}
EOF_ENV

scp "$TMP_ENV" "${APP_USER}@${VPS_HOST}:/tmp/runtime.env"
ssh "${APP_USER}@${VPS_HOST}" "sudo mkdir -p $(dirname "$RUNTIME_ENV_REMOTE") && sudo mv /tmp/runtime.env ${RUNTIME_ENV_REMOTE} && sudo chmod 600 ${RUNTIME_ENV_REMOTE} && sudo chown ${APP_USER}:${APP_USER} ${RUNTIME_ENV_REMOTE}"

rm -f "$TMP_ENV"
