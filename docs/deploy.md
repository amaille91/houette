# Deployment Guide (Debian 12)

This guide describes how to deploy the backend (`foucl2`) and frontend (`favs-frontend2`) to a single Debian 12 VPS using Nginx, systemd, and Let's Encrypt.

## Quick Start (One Command)

```bash
make full-deploy CONFIG=/path/to/config.env
```

The full pipeline does:
1. Bootstrap (user, packages, directories, SSH key)
2. Update local `~/.ssh/config`
3. Sudoers setup (non-interactive deploy)
4. Firewall (UFW)
5. Runtime env upload
6. systemd unit deploy
7. Nginx config deploy (HTTP)
8. TLS via Certbot
9. Nginx config deploy (HTTPS)
10. Frontend deploy
11. Backend deploy
12. Health checks

## Required Configuration

Create a local file (not committed) based on:

```bash
cp deploy/config.env.example /path/to/config.env
```

Important variables:
- `ROOT_USER` (initial SSH user with sudo, usually `root`)
- `APP_USER` (app runtime user, created by bootstrap)
- `APP_ROOT` (absolute path, e.g. `/home/foucl/apps`)
- `DOMAIN` and `ACME_EMAIL`
- `LOCAL_FRONTEND_FILES` (local build dir with `index.html`)
- `BACKEND_BINARY`, `BACKEND_CONFIG_FILE`
- `FOUCL_SESSION_SECRET`

## Directory Layout on the VPS

```
APP_ROOT/
  foucl/
    foucl                  # backend binary
    config/
      app-config.json      # backend config (non-secret)
      runtime.env          # secrets/env (generated from config.env)
    data/                  # notes/checklists/agenda/session storage
    static/                # frontend static assets
    server.log             # backend logs
  favs/
    index.html             # copied from static bundle
    static/                # frontend assets (index.js, css, bootstrap, icons)
```

## Core Scripts

- `scripts/full_deploy.sh` – one command end-to-end pipeline
- `scripts/bootstrap_vps.sh` – user + packages + directories + SSH key
- `scripts/setup_sudoers.sh` – sudoers for non-interactive deploy
- `scripts/setup_firewall.sh` – UFW config
- `scripts/deploy_runtime_env.sh` – runtime env generation/upload
- `scripts/deploy_systemd.sh` – systemd unit install + enable
- `scripts/deploy_nginx.sh` – nginx config deploy with HTTP/HTTPS switch
- `scripts/certbot_tls.sh` – cert issuance (idempotent)
- `scripts/deploy_front.sh` – deploy static assets to `APP_ROOT/favs/static`
- `scripts/deploy_back.sh` – deploy backend binary + config
- `scripts/health_check.sh` – systemd + HTTPS checks

## Manual / Individual Steps

```bash
make bootstrap CONFIG=/path/to/config.env
make update-ssh-config CONFIG=/path/to/config.env
make sudoers CONFIG=/path/to/config.env
make firewall CONFIG=/path/to/config.env
make deploy-runtime-env CONFIG=/path/to/config.env
make deploy-systemd CONFIG=/path/to/config.env
make deploy-nginx CONFIG=/path/to/config.env
make certbot CONFIG=/path/to/config.env
make deploy-nginx CONFIG=/path/to/config.env
make deploy-front CONFIG=/path/to/config.env
make deploy-back CONFIG=/path/to/config.env
make health-check CONFIG=/path/to/config.env
```

## Notes and Choices
- Nginx serves static files from `APP_ROOT/favs` with assets in `APP_ROOT/favs/static`.
- SPA routes are handled by `try_files ... /index.html`.
- Backend listens on `127.0.0.1:8081` and is proxied via `/api`.
- Certbot runs non-interactively; HTTPS is activated after cert issuance.
- SSH access uses keys; the app user has password disabled.

## Validation

```bash
make health-check CONFIG=/path/to/config.env
```

## Backups

```bash
make backup CONFIG=/path/to/config.env
```
