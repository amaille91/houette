#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=${1:-}
if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: $0 /path/to/config.env" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [ -z "${VPS_HOST:-}" ] || [ -z "${ROOT_USER:-}" ] || [ -z "${APP_USER:-}" ]; then
  echo "VPS_HOST, ROOT_USER, and APP_USER are required in config" >&2
  exit 1
fi

echo "[sudoers] Connecting to ${ROOT_USER}@${VPS_HOST}"

ssh "${ROOT_USER}@${VPS_HOST}" APP_USER="${APP_USER}" bash -s <<'REMOTE'
set -euo pipefail

echo "[sudoers] Writing /etc/sudoers.d/foucl-deploy"
SUDOERS_FILE="/etc/sudoers.d/foucl-deploy"

sudo tee "$SUDOERS_FILE" >/dev/null <<SUDOERS
# Allow deployment actions without password
${APP_USER} ALL=(ALL) NOPASSWD: /usr/sbin/nginx, /usr/bin/certbot, /bin/systemctl, /usr/bin/journalctl, /usr/sbin/ufw, /bin/mv, /bin/ln, /bin/cp, /bin/rm, /bin/mkdir, /usr/bin/tee, /usr/bin/chmod, /usr/bin/chown, /usr/bin/tail, /usr/bin/cat, /usr/bin/find, /usr/bin/test, /bin/test
SUDOERS

echo "[sudoers] Setting permissions"
sudo chmod 440 "$SUDOERS_FILE"

echo "[sudoers] Done"
REMOTE
