#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=${1:-}
if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: $0 /path/to/config.env" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

validate_paths() {
  local missing=0

  if [ -z "${LOCAL_FRONTEND_FILES:-}" ] || [ ! -d "$LOCAL_FRONTEND_FILES" ]; then
    echo "[full-deploy] LOCAL_FRONTEND_FILES missing or not a directory: ${LOCAL_FRONTEND_FILES:-<unset>}" >&2
    missing=1
  fi

  if [ -z "${BACKEND_BINARY:-}" ] || [ ! -f "$BACKEND_BINARY" ]; then
    echo "[full-deploy] BACKEND_BINARY missing or not a file: ${BACKEND_BINARY:-<unset>}" >&2
    missing=1
  fi

  if [ -z "${BACKEND_CONFIG_FILE:-}" ] || [ ! -f "$BACKEND_CONFIG_FILE" ]; then
    echo "[full-deploy] BACKEND_CONFIG_FILE missing or not a file: ${BACKEND_CONFIG_FILE:-<unset>}" >&2
    missing=1
  fi

  if [ -z "${APP_ROOT:-}" ] || [[ "${APP_ROOT}" != /* ]]; then
    echo "[full-deploy] APP_ROOT must be an absolute path: ${APP_ROOT:-<unset>}" >&2
    missing=1
  fi

  if [ $missing -ne 0 ]; then
    echo "[full-deploy] Path validation failed" >&2
    exit 2
  fi
}

validate_paths

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

log_step() {
  echo ""
  echo "===================="
  echo "[full-deploy] $1"
  echo "===================="
}

log_step "Bootstrap VPS"
"$SCRIPT_DIR/bootstrap_vps.sh" "$CONFIG_FILE"

log_step "Update local SSH config"
"$SCRIPT_DIR/update_ssh_config.sh" "$CONFIG_FILE"

log_step "Configure sudoers"
"$SCRIPT_DIR/setup_sudoers.sh" "$CONFIG_FILE"

log_step "Configure firewall (UFW)"
"$SCRIPT_DIR/setup_firewall.sh" "$CONFIG_FILE"

log_step "Deploy runtime env"
"$SCRIPT_DIR/deploy_runtime_env.sh" "$CONFIG_FILE"

log_step "Deploy systemd unit"
"$SCRIPT_DIR/deploy_systemd.sh" "$CONFIG_FILE"

log_step "Deploy Nginx config"
"$SCRIPT_DIR/deploy_nginx.sh" "$CONFIG_FILE"

log_step "Obtain TLS certificate"
"$SCRIPT_DIR/certbot_tls.sh" "$CONFIG_FILE"

log_step "Deploy Nginx config (post-TLS)"
"$SCRIPT_DIR/deploy_nginx.sh" "$CONFIG_FILE"

log_step "Deploy frontend assets"
"$SCRIPT_DIR/deploy_front.sh" "$CONFIG_FILE"

log_step "Deploy backend binary"
"$SCRIPT_DIR/deploy_back.sh" "$CONFIG_FILE"

log_step "Health checks"
"$SCRIPT_DIR/health_check.sh" "$CONFIG_FILE"
