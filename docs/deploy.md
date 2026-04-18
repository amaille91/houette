# Deployment Guide (Debian 12)

This repo deploys the backend (`foucl2`) and frontend (`favs-frontend2`) to a single Debian 12 VPS using native PostgreSQL, Nginx, systemd, and Let's Encrypt.

## Quick Start

```bash
make full-deploy CONFIG=/path/to/config.env
```

The full pipeline does:
1. Bootstrap the VPS user/directories/base packages
2. Update local `~/.ssh/config`
3. Install deploy sudoers rules
4. Configure UFW
5. Install and start PostgreSQL
6. Provision the foucl DB role and database
7. Upload runtime env
8. Install the `foucl` systemd unit
9. Deploy Nginx (HTTP)
10. Obtain TLS via Certbot
11. Re-deploy Nginx (HTTPS)
12. Deploy frontend assets
13. Deploy backend binary, config, and SQL migration files
14. Run health checks

## Required Configuration

Start from:

```bash
cp deploy/config.env.example /path/to/config.env
```

Important variables:
- `ROOT_USER`, `APP_USER`, `VPS_HOST`, `APP_ROOT`
- `DOMAIN`, `ACME_EMAIL`
- `FOUCL_SESSION_SECRET`
- `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
- `LOCAL_FRONTEND_FILES`
- `BACKEND_BINARY`
- `BACKEND_MIGRATIONS_DIR`
- `BACKEND_CONFIG_FILE`
- `FILES_BACKUP_DEST`
- `POSTGRES_BACKUP_DEST`

`foucl` reads database settings from `app-config.json`, not from `runtime.env`. The JSON config deployed to the VPS must therefore include a top-level `database` object plus Postgres backend selections for the domains you want to run on Postgres.

## VPS Layout

```text
APP_ROOT/
  foucl/
    foucl
    config/
      app-config.json
      runtime.env
    db/
      migrations/
        auth/
        session/
        calendar/
        trip-sharing/
        note/
        checklist/
    data/                  # retained for legacy filesystem import / rollback
  favs/
    index.html
    static/
```

PostgreSQL data itself remains under Debian's native Postgres directories and is managed by `postgresql.service`.

## Manual Steps

```bash
make bootstrap CONFIG=/path/to/config.env
make update-ssh-config CONFIG=/path/to/config.env
make sudoers CONFIG=/path/to/config.env
make firewall CONFIG=/path/to/config.env
make deploy-postgres CONFIG=/path/to/config.env
make deploy-runtime-env CONFIG=/path/to/config.env
make deploy-systemd CONFIG=/path/to/config.env
make deploy-nginx CONFIG=/path/to/config.env
make certbot CONFIG=/path/to/config.env
make deploy-nginx CONFIG=/path/to/config.env
make deploy-front CONFIG=/path/to/config.env
make deploy-back CONFIG=/path/to/config.env
make health-check CONFIG=/path/to/config.env
```

## Runtime Behavior

- `postgresql.service` is the database lifecycle owner. This repo installs it, enables it, and starts it through systemd.
- `foucl.service` starts after `postgresql.service`.
- `foucl` runs startup migrations automatically for all domains configured with backend `postgres`.
- Startup hard-fails if Postgres is unreachable, if `psql` is missing, or if a migration fails.
- `deploy-back` syncs `db/migrations` to the VPS because the backend reads SQL files from `./db/migrations/...` at runtime.

## Validation

```bash
make health-check CONFIG=/path/to/config.env
```

Health checks verify:
- `postgresql.service` is active
- the configured DB credentials can run `SELECT 1`
- `foucl.service` is active
- frontend returns HTTP 200
- `/api/note` returns HTTP 200 or 401

## Backups

Filesystem backup of legacy `APP_ROOT/foucl/data`:

```bash
make backup-files CONFIG=/path/to/config.env
```

PostgreSQL backup using `pg_dump`:

```bash
make backup-postgres CONFIG=/path/to/config.env
```

`make backup` remains as a legacy alias for `make backup-files`.

## Restores

Restore legacy filesystem snapshot:

```bash
make restore-files CONFIG=/path/to/config.env FILES_BACKUP_SOURCE=/path/to/files-backup
```

Restore PostgreSQL from a SQL dump:

```bash
make restore-postgres CONFIG=/path/to/config.env DUMP_FILE=/path/to/postgres.sql
```

Both restore flows stop `foucl` before writing data and start it again afterward if it was active before the restore.
