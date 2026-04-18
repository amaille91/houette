CONFIG ?= ./deploy.env
RENDER_OUT ?= ./rendered

.PHONY: help render deploy-front deploy-back deploy-postgres backup backup-files restore-files backup-postgres restore-postgres bootstrap firewall deploy-nginx deploy-systemd deploy-runtime-env certbot health-check sudoers full-deploy update-ssh-config

help:
	@echo "Targets:"
	@echo "  render              Render nginx/systemd templates"
	@echo "  deploy-front        Deploy frontend static files"
	@echo "  deploy-back         Deploy backend binary/config"
	@echo "  deploy-postgres     Install PostgreSQL and provision foucl DB/user"
	@echo "  deploy-nginx        Deploy nginx config and reload"
	@echo "  deploy-systemd      Deploy systemd unit and enable service"
	@echo "  deploy-runtime-env  Upload runtime.env (generated)"
	@echo "  certbot             Obtain TLS cert via Let's Encrypt"
	@echo "  firewall            Configure UFW rules"
	@echo "  bootstrap           Install packages and create user/dirs"
	@echo "  sudoers             Install sudoers rules for deploy"
	@echo "  health-check        Validate service and HTTP endpoints"
	@echo "  backup-files        Backup legacy filesystem data"
	@echo "  restore-files       Restore legacy filesystem data"
	@echo "  backup-postgres     Backup PostgreSQL using pg_dump"
	@echo "  restore-postgres    Restore PostgreSQL from a SQL dump"
	@echo "  backup              Legacy alias for backup-files"
	@echo "  update-ssh-config   Idempotently update ~/.ssh/config"
	@echo "  full-deploy         Run full end-to-end deployment"
	@echo ""
	@echo "Variables:"
	@echo "  CONFIG=/path/to/config.env"
	@echo "  RENDER_OUT=/path/to/rendered"
	@echo "  FILES_BACKUP_SOURCE=/path/to/files-backup"
	@echo "  DUMP_FILE=/path/to/postgres.sql"

render:
	@./scripts/render_templates.sh "$(CONFIG)" "$(RENDER_OUT)"

deploy-front:
	@./scripts/deploy_front.sh "$(CONFIG)"

deploy-back:
	@./scripts/deploy_back.sh "$(CONFIG)"

deploy-postgres:
	@./scripts/deploy_postgres.sh "$(CONFIG)"

deploy-nginx:
	@./scripts/deploy_nginx.sh "$(CONFIG)"

deploy-systemd:
	@./scripts/deploy_systemd.sh "$(CONFIG)"

deploy-runtime-env:
	@./scripts/deploy_runtime_env.sh "$(CONFIG)"

certbot:
	@./scripts/certbot_tls.sh "$(CONFIG)"

firewall:
	@./scripts/setup_firewall.sh "$(CONFIG)"

bootstrap:
	@./scripts/bootstrap_vps.sh "$(CONFIG)"

sudoers:
	@./scripts/setup_sudoers.sh "$(CONFIG)"

health-check:
	@./scripts/health_check.sh "$(CONFIG)"

update-ssh-config:
	@./scripts/update_ssh_config.sh "$(CONFIG)"

full-deploy:
	@./scripts/full_deploy.sh "$(CONFIG)"

backup:
	@./scripts/backup_files.sh "$(CONFIG)"

backup-files:
	@./scripts/backup_files.sh "$(CONFIG)"

restore-files:
	@./scripts/restore_files.sh "$(CONFIG)" "$(FILES_BACKUP_SOURCE)"

backup-postgres:
	@./scripts/backup_postgres.sh "$(CONFIG)"

restore-postgres:
	@./scripts/restore_postgres.sh "$(CONFIG)" "$(DUMP_FILE)"
