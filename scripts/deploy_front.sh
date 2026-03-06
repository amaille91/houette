#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=${1:-}
if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: $0 /path/to/config.env" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [ -z "${LOCAL_FRONTEND_FILES:-}" ]; then
  echo "LOCAL_FRONTEND_FILES is required in config" >&2
  exit 1
fi

if [ -z "${VPS_HOST:-}" ] || [ -z "${APP_USER:-}" ] || [ -z "${APP_ROOT:-}" ]; then
  echo "VPS_HOST, APP_USER, and APP_ROOT are required in config" >&2
  exit 1
fi

if [ ! -d "$LOCAL_FRONTEND_FILES" ]; then
  echo "LOCAL_FRONTEND_FILES does not exist: ${LOCAL_FRONTEND_FILES}" >&2
  exit 1
fi

if [ ! -f "$LOCAL_FRONTEND_FILES/index.html" ]; then
  echo "LOCAL_FRONTEND_FILES missing index.html: ${LOCAL_FRONTEND_FILES}/index.html" >&2
  exit 1
fi

FAVS_DIR="${APP_ROOT%/}/favs"
STATIC_DIR="${FAVS_DIR%/}/static"

# Ensure remote target exists
ssh "${APP_USER}@${VPS_HOST}" "mkdir -p ${STATIC_DIR}"

rsync -av "${LOCAL_FRONTEND_FILES%/}/" "${APP_USER}@${VPS_HOST}:${STATIC_DIR%/}/"

# Place index.html at the root for nginx (root points to ${APP_ROOT}/favs)
ssh "${APP_USER}@${VPS_HOST}" "cp ${STATIC_DIR}/index.html ${FAVS_DIR}/index.html"

# Ensure nginx can read the files (www-data needs rx on dirs and r on files)
ssh "${APP_USER}@${VPS_HOST}" "sudo chmod o+rx /home/${APP_USER} /home/${APP_USER}/apps ${FAVS_DIR} ${STATIC_DIR} && sudo find ${STATIC_DIR} -type d -exec chmod o+rx {} \\; && sudo find ${STATIC_DIR} -type f -exec chmod o+r {} \\; && sudo chmod o+r ${FAVS_DIR}/index.html"
