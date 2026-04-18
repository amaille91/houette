# Deployment Overview (VPS, Debian 12)

## Goals
- Provide a simple, reliable deployment for a private web app with low expected traffic.
- Serve the frontend as static files over HTTPS.
- Run the backend as a systemd service, reachable only on localhost.
- Run PostgreSQL locally on the VPS and manage it with systemd.
- Use Nginx as reverse proxy for `/api` and to terminate TLS.
- Keep secrets and sensitive parameters outside the repo.
- Enable separate manual backups for legacy filesystem data and live PostgreSQL data.
- One-command end-to-end deployment with minimal manual steps.

## Scope
In scope:
- Single VPS, Debian 12.
- Nginx + Let's Encrypt (Certbot).
- Backend Haskell service + static frontend.
- Native PostgreSQL on the same VPS.
- Filesystem-to-Postgres startup import support.
- Manual filesystem backup via rsync.
- Manual PostgreSQL backup via `pg_dump`.
- Idempotent automation scripts for bootstrap, PostgreSQL, firewall, and nginx.
- One-command full deployment pipeline.

Out of scope:
- Multi-node or high-availability setups.
- Managed databases.
- Full CI/CD pipelines.

## Key Technical Choices
- **Debian 12**: Stable, well-documented, good defaults.
- **Nginx**: Reverse proxy + static file server.
- **systemd**: Native service manager for the backend and PostgreSQL lifecycle.
- **PostgreSQL**: Native local database for foucl persistence.
- **Let's Encrypt**: Automated TLS certs via Certbot.
- **SQL migration files**: Reviewed and deployed as artifacts; executed by foucl startup.
- **Idempotent scripts**: Reproducible bootstrap + deploy.
- **Single root directory**: All app artifacts under `APP_ROOT`.

## Target Architecture (Text Diagram)

```text
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
            [PostgreSQL]
```

## Deployment Structure

### App root (APP_ROOT)
All application files live under `APP_ROOT` (e.g. `/home/foucl/apps`).

```text
APP_ROOT/
  foucl/
    foucl                  # backend binary
    config/
      app-config.json      # backend config (non-secret)
      runtime.env          # secrets/env (generated from config.env)
    db/
      migrations/          # SQL migrations required at foucl startup
    data/                  # legacy filesystem data kept for startup import / rollback
  favs/
    index.html             # copied from static bundle
    static/                # frontend assets (index.js, css, bootstrap, icons)
```

Notes:
- Nginx serves `APP_ROOT/favs/index.html` for SPA routes and `APP_ROOT/favs/static/*` for assets.
- Backend service uses `WorkingDirectory=APP_ROOT/foucl`.
- PostgreSQL cluster files stay in Debian-managed system paths, not under `APP_ROOT`.

## Security Model
- HTTPS enforced at the reverse proxy.
- Backend bound to `127.0.0.1:8081` only.
- Secrets provided via a runtime env file on the VPS.
- PostgreSQL is expected to be reachable on localhost only.
- Firewall (UFW) allows only 22/80/443.
- SSH access via key; password disabled for app user.

## End-to-End Deployment Flow
1. Bootstrap VPS (user + packages + directories + SSH key).
2. Update local SSH config (idempotent).
3. Configure sudoers for non-interactive deploy.
4. Configure firewall (UFW).
5. Install PostgreSQL packages if missing and start `postgresql.service`.
6. Create or update the foucl DB role and database.
7. Deploy runtime env.
8. Deploy systemd unit.
9. Deploy Nginx config (HTTP if no cert).
10. Obtain TLS certificate (Certbot).
11. Re-deploy Nginx config (HTTPS).
12. Deploy frontend assets.
13. Deploy backend binary, app config, and migration SQL files.
14. Health checks (PostgreSQL + foucl + HTTPS endpoints).

## Rollback Strategy
- Keep a previous version of the backend binary and static files on the VPS.
- Keep legacy filesystem snapshots and PostgreSQL logical dumps on the dev machine.
- If needed, restore the appropriate backup, redeploy the matching binary/config, and restart services.

## Backup and Restore
- Filesystem backup:
  - rsync `APP_ROOT/foucl/data` to the dev machine.
  - restore by rsyncing it back with `foucl` stopped.
- PostgreSQL backup:
  - run `pg_dump` remotely and save the SQL dump locally.
  - restore by stopping `foucl`, replaying the SQL dump through `psql`, then starting `foucl`.
- The two backup flows are intentionally separate. Filesystem backup preserves legacy import data; PostgreSQL backup preserves live application state.

## Troubleshooting Checklist
- `systemctl status postgresql`
- `journalctl -u postgresql -e`
- `PGPASSWORD=... psql --host 127.0.0.1 --port 5432 --username foucl --dbname foucl`
- `systemctl status foucl`
- `journalctl -u foucl -e`
- `nginx -t` and `systemctl reload nginx`
- `certbot certificates -d <domain>`
- `curl -I https://<domain>/` and `curl -I https://<domain>/api/note`
