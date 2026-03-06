# Deployment Overview (VPS, Debian 12)

## Goals
- Provide a simple, reliable deployment for a private web app with low expected traffic.
- Serve the frontend as static files over HTTPS.
- Run the backend as a systemd service, reachable only on localhost.
- Use Nginx as reverse proxy for `/api` and to terminate TLS.
- Keep secrets and sensitive parameters outside the repo.
- Enable manual backups of file-based data to the dev machine.
- One-command end-to-end deployment with minimal manual steps.

## Scope
In scope:
- Single VPS, Debian 12.
- Nginx + Let's Encrypt (Certbot).
- Backend Haskell service + static frontend.
- File-based storage under the app directory.
- Manual backups via rsync.
- Idempotent automation scripts for bootstrap, firewall, and nginx.
- One-command full deployment pipeline.

Out of scope:
- Multi-node or high-availability setups.
- Managed databases.
- Full CI/CD pipelines.

## Key Technical Choices
- **Debian 12**: Stable, well-documented, good defaults.
- **Nginx**: Reverse proxy + static file server.
- **systemd**: Native service manager for the backend.
- **Let's Encrypt**: Automated TLS certs via Certbot.
- **File storage**: Backend persists data to local files.
- **Idempotent scripts**: Reproducible bootstrap + deploy.
- **Single root directory**: All app files under `APP_ROOT`.

## Target Architecture (Text Diagram)

```
Internet
  |
  | HTTPS (443)
  v
[Nginx]
  |   \
  |    \-- serves / (frontend static)
  |
  \-- proxies /api -> http://127.0.0.1:8081/api
                 |
                 v
            [Backend service]
                 |
                 v
           file storage (data/)
```

## Deployment Structure

### App root (APP_ROOT)
All application files live under `APP_ROOT` (e.g. `/home/foucl/apps`).

```
APP_ROOT/
  foucl/
    foucl                  # backend binary
    config/
      app-config.json      # backend config (non-secret)
      runtime.env          # secrets/env (generated from config.env)
    data/                  # notes/checklists/agenda/session storage
    static/                # frontend static assets
    server.log             # backend logs (append)
  favs/
    index.html             # copied from static bundle
    static/                # frontend assets (index.js, css, bootstrap, icons)
```

Notes:
- Nginx serves `APP_ROOT/favs/index.html` for SPA routes and `APP_ROOT/favs/static/*` for assets.
- Backend service uses `WorkingDirectory=APP_ROOT/foucl`.

## Security Model
- HTTPS enforced at the reverse proxy.
- Backend bound to `127.0.0.1:8081` only.
- Secrets provided via a runtime env file on the VPS.
- Firewall (UFW) allows only 22/80/443.
- SSH access via key; password disabled for app user.

## End-to-End Deployment Flow
1. Bootstrap VPS (user + packages + directories + SSH key).
2. Update local SSH config (idempotent).
3. Configure sudoers for non-interactive deploy.
4. Configure firewall (UFW).
5. Deploy runtime env.
6. Deploy systemd unit.
7. Deploy Nginx config (HTTP if no cert).
8. Obtain TLS certificate (Certbot).
9. Re-deploy Nginx config (HTTPS).
10. Deploy frontend assets.
11. Deploy backend binary + config.
12. Health checks (systemd + HTTPS endpoints).

## Rollback Strategy
- Keep a previous version of the backend binary and static files on the VPS.
- If needed, replace the current files with the previous version and restart.

## Backup and Restore
- Manual rsync of `APP_ROOT/foucl/data` to the dev machine.
- Restore by rsync back to the VPS with the backend service stopped.

## Troubleshooting Checklist
- `systemctl status foucl`
- `journalctl -u foucl -e`
- `nginx -t` and `systemctl reload nginx`
- `certbot certificates -d <domain>`
- `curl -I https://<domain>/` and `curl -I https://<domain>/api/note`
