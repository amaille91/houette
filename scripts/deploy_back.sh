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

if [ -z "${BACKEND_CONFIG_FILE:-}" ]; then
  echo "BACKEND_CONFIG_FILE is required in config" >&2
  exit 1
fi

if [ ! -f "$BACKEND_BINARY" ]; then
  echo "BACKEND_BINARY does not exist: ${BACKEND_BINARY}" >&2
  exit 1
fi

if [ ! -f "$BACKEND_CONFIG_FILE" ]; then
  echo "BACKEND_CONFIG_FILE does not exist: ${BACKEND_CONFIG_FILE}" >&2
  exit 1
fi

if [ -z "${VPS_HOST:-}" ] || [ -z "${APP_USER:-}" ] || [ -z "${APP_ROOT:-}" ]; then
  echo "VPS_HOST, APP_USER, and APP_ROOT are required in config" >&2
  exit 1
fi

FOUCL_DIR="${APP_ROOT%/}/foucl"

echo "[deploy-back] Ensuring remote directories exist"
ssh "${APP_USER}@${VPS_HOST}" "mkdir -p ${FOUCL_DIR%/}/config && mkdir -p ${FOUCL_DIR%/}"

echo "[deploy-back] Uploading backend binary to /tmp"
scp "$BACKEND_BINARY" "${APP_USER}@${VPS_HOST}:/tmp/foucl.bin"

echo "[deploy-back] Installing backend binary"
ssh "${APP_USER}@${VPS_HOST}" "mv /tmp/foucl.bin ${FOUCL_DIR%/}/foucl && chmod +x ${FOUCL_DIR%/}/foucl"

echo "[deploy-back] Uploading app-config.json"
scp "$BACKEND_CONFIG_FILE" "${APP_USER}@${VPS_HOST}:${FOUCL_DIR%/}/config/app-config.json"

echo "[deploy-back] Restarting service"
ssh "${APP_USER}@${VPS_HOST}" "sudo systemctl restart foucl"
