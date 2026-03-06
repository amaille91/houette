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

SSH_CONFIG="${HOME}/.ssh/config"
mkdir -p "${HOME}/.ssh"

BLOCK_START="# BEGIN FOUCL MANAGED ${VPS_HOST}"
BLOCK_END="# END FOUCL MANAGED ${VPS_HOST}"

TMP_FILE=$(mktemp)

# Remove existing managed block for this host, if any
if [ -f "$SSH_CONFIG" ]; then
  awk -v start="$BLOCK_START" -v end="$BLOCK_END" '
    $0==start {skip=1; next}
    $0==end {skip=0; next}
    skip==0 {print}
  ' "$SSH_CONFIG" > "$TMP_FILE"
else
  : > "$TMP_FILE"
fi

{
  echo "$BLOCK_START"
  echo "Host ${VPS_HOST}"
  echo "  User ${APP_USER}"
  echo "  IdentityFile ~/.ssh/${APP_USER}"
  echo "$BLOCK_END"
} >> "$TMP_FILE"

mv "$TMP_FILE" "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

echo "Updated ${SSH_CONFIG} for host ${VPS_HOST}"
