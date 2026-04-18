#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=${1:-}
if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: $0 /path/to/config.env" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [ -z "${VPS_HOST:-}" ] || [ -z "${ROOT_USER:-}" ] || [ -z "${APP_USER:-}" ] || [ -z "${APP_ROOT:-}" ]; then
  echo "VPS_HOST, ROOT_USER, APP_USER, and APP_ROOT are required in config" >&2
  exit 1
fi

resolve_pubkey() {
  local host="$1"
  local user="$2"

  # If SSH_PUBKEY_PATH is provided, honor it.
  if [ -n "${SSH_PUBKEY_PATH:-}" ] && [ -f "$SSH_PUBKEY_PATH" ]; then
    echo "$SSH_PUBKEY_PATH"
    return 0
  fi

  # Prefer a local key named after APP_USER (auto-create if missing).
  local user_key_base="${HOME}/.ssh/${APP_USER}"
  if [ ! -f "${user_key_base}.pub" ]; then
    echo "[bootstrap] Generating SSH key ${user_key_base}" >&2
    ssh-keygen -t ed25519 -f "${user_key_base}" -N "" -C "${APP_USER}@${VPS_HOST}" >/dev/null
  fi
  if [ -f "${user_key_base}.pub" ]; then
    echo "${user_key_base}.pub"
    return 0
  fi

  # Try to infer from ssh config (IdentityFile entries).
  local identity
  identity=$(ssh -G "${user}@${host}" 2>/dev/null | awk '/^identityfile /{print $2}' | head -n 1 || true)
  if [ -n "$identity" ]; then
    if [ -f "${identity}.pub" ]; then
      echo "${identity}.pub"
      return 0
    fi
    if [ -f "${identity}" ] && [[ "$identity" == *.pub ]]; then
      echo "$identity"
      return 0
    fi
  fi

  # Fallbacks
  if [ -f "${HOME}/.ssh/id_rsa.pub" ]; then
    echo "${HOME}/.ssh/id_rsa.pub"
    return 0
  fi
  if [ -f "${HOME}/.ssh/id_ed25519.pub" ]; then
    echo "${HOME}/.ssh/id_ed25519.pub"
    return 0
  fi

  return 1
}

PUBKEY_PATH=$(resolve_pubkey "$VPS_HOST" "$ROOT_USER" || true)
if [ -z "$PUBKEY_PATH" ] || [ ! -f "$PUBKEY_PATH" ]; then
  echo "SSH public key not found. Set SSH_PUBKEY_PATH in config." >&2
  exit 1
fi

PUBKEY_CONTENT=$(cat "$PUBKEY_PATH")

echo "[bootstrap] Using SSH public key: ${PUBKEY_PATH}"
echo "[bootstrap] Connecting to ${ROOT_USER}@${VPS_HOST}"

ssh "${ROOT_USER}@${VPS_HOST}" bash -s <<REMOTE
set -euo pipefail

echo "[bootstrap] Ensuring user ${APP_USER} exists"
if ! id -u "${APP_USER}" >/dev/null 2>&1; then
  sudo adduser --disabled-password --gecos "" "${APP_USER}"
fi

echo "[bootstrap] Ensuring ${APP_USER} is in sudo group"
if ! id -nG "${APP_USER}" | grep -qw sudo; then
  sudo usermod -aG sudo "${APP_USER}"
fi

echo "[bootstrap] Installing packages"
sudo apt-get update -y
sudo apt-get install -y nginx certbot python3-certbot-nginx rsync ufw

echo "[bootstrap] Creating directories under ${APP_ROOT}"
sudo mkdir -p "${APP_ROOT}/foucl/data"
sudo mkdir -p "${APP_ROOT}/foucl/config"
sudo mkdir -p "${APP_ROOT}/foucl/db"
sudo mkdir -p "${APP_ROOT}/favs"

echo "[bootstrap] Setting ownership"
sudo chown -R "${APP_USER}:${APP_USER}" "${APP_ROOT}"

echo "[bootstrap] Installing SSH key for ${APP_USER}"
sudo -u "${APP_USER}" mkdir -p "/home/${APP_USER}/.ssh"
sudo chmod 700 "/home/${APP_USER}/.ssh"
if [ -f "/home/${APP_USER}/.ssh/authorized_keys" ]; then
  sudo cp "/home/${APP_USER}/.ssh/authorized_keys" "/home/${APP_USER}/.ssh/authorized_keys.bak"
fi
printf '%s\n' "${PUBKEY_CONTENT}" | sudo tee -a "/home/${APP_USER}/.ssh/authorized_keys" >/dev/null
sudo sort -u "/home/${APP_USER}/.ssh/authorized_keys" -o "/home/${APP_USER}/.ssh/authorized_keys"
sudo chmod 600 "/home/${APP_USER}/.ssh/authorized_keys"
sudo chown -R "${APP_USER}:${APP_USER}" "/home/${APP_USER}/.ssh"

echo "[bootstrap] Done"
REMOTE
