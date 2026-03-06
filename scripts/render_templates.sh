#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=${1:-}
if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: $0 /path/to/config.env" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if ! command -v envsubst >/dev/null 2>&1; then
  echo "envsubst not found. Install gettext (e.g., apt install gettext)." >&2
  exit 1
fi

if [ -z "${APP_ROOT:-}" ] || [ -z "${APP_USER:-}" ]; then
  echo "APP_ROOT and APP_USER are required in config" >&2
  exit 1
fi

if [ -z "${DOMAIN:-}" ]; then
  echo "DOMAIN is required in config" >&2
  exit 1
fi

if [ -z "${RUNTIME_ENV:-}" ]; then
  RUNTIME_ENV="${APP_ROOT%/}/foucl/config/runtime.env"
fi

export APP_ROOT APP_USER DOMAIN RUNTIME_ENV

OUT_DIR=${2:-./rendered}
mkdir -p "$OUT_DIR"

envsubst '$APP_ROOT $DOMAIN' < "$(dirname "$0")/../deploy/nginx/site.conf.template" > "$OUT_DIR/nginx.conf"
envsubst '$APP_ROOT $APP_USER $RUNTIME_ENV' < "$(dirname "$0")/../deploy/systemd/foucl.service" > "$OUT_DIR/foucl.service"

printf "Rendered to %s\n" "$OUT_DIR"
