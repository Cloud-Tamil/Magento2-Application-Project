.PHONY: help build up down restart ps logs logs-app logs-nginx bash cli install permissions cache-clean cache-flush reindex compile setup-upgrade test terraform-dev-plan terraform-dev-apply

# Default target
help:
	@echo "=========================================================================="
	@echo "           MAGENTO 2 ENTERPRISE DEVOPS - COMMAND SUITE                    "
	@echo "=========================================================================="
	@echo "Local Development:"
	@echo "  make build             - Build all Docker images"
	@echo "  make up                - Start all local containers (detached mode)"
	@echo "  make down              - Stop and remove containers and networks"
	@echo "  make restart           - Restart all containers"
	@echo "  make ps                - Show running containers status and health"
	@echo "  make logs              - Stream logs from all services"
	@echo "  make bash              - Open bash inside Magento application container"
	@echo "  make install           - Run automated Magento 2 setup installer"
	@echo "  make permissions       - Fix file ownership and permissions"
	@echo ""
	@echo "Magento Maintenance:"
	@echo "  make cache-clean       - Clean Magento cache types"
	@echo "  make cache-flush       - Flush Magento cache storage"
	@echo "  make reindex           - Trigger full catalog reindex via OpenSearch"
	@echo "  make compile           - Run dependency injection compilation (di:compile)"
	@echo "  make setup-upgrade     - Upgrade Magento schema and data modules"
	@echo ""
	@echo "Terraform Infrastructure:"
	@echo "  make tf-init-dev       - Initialize Terraform for dev environment"
	@echo "  make tf-plan-dev       - Run terraform plan for dev"
	@echo "  make tf-apply-dev      - Run terraform apply for dev"
	@echo ""
	@echo "Monitoring Suite:"
	@echo "  make monitoring-up     - Start Prometheus (port 9090) and Grafana (port 3001)"
	@echo "  make monitoring-down   - Stop Prometheus and Grafana"
	@echo "  make monitoring-logs   - Follow Prometheus and Grafana logs"
	@echo "=========================================================================="

build:
	docker compose build

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down && docker compose up -d

ps:
	docker compose ps

logs:
	docker compose logs -f

logs-app:
	docker compose logs -f magento

logs-nginx:
	docker compose logs -f nginx

bash:
	docker compose exec -it magento bash

cli:
	docker compose exec -it -u www-data magento bash

install:
	chmod +x scripts/*.sh
	./scripts/install-magento.sh

permissions:
	chmod +x scripts/permissions.sh
	./scripts/permissions.sh

cache-clean:
	docker compose exec -u www-data magento bin/magento cache:clean

cache-flush:
	docker compose exec -u www-data magento bin/magento cache:flush

reindex:
	docker compose exec -u www-data magento bin/magento indexer:reindex

compile:
	docker compose exec -u www-data magento bin/magento setup:di:compile

setup-upgrade:
	docker compose exec -u www-data magento bin/magento setup:upgrade --keep-generated

health-check:
	chmod +x scripts/health-check.sh
	./scripts/health-check.sh

tf-init-dev:
	cd terraform/environments/dev && terraform init

tf-plan-dev:
	cd terraform/environments/dev && terraform plan

tf-apply-dev:
	cd terraform/environments/dev && terraform apply

monitoring-up:
	docker compose up -d prometheus grafana

monitoring-down:
	docker compose stop prometheus grafana

monitoring-logs:
	docker compose logs -f prometheus grafana

optimize:
	chmod +x scripts/optimize.sh
	./scripts/optimize.sh

backup:
	chmod +x scripts/backup.sh
	./scripts/backup.sh

restore:
	chmod +x scripts/restore.sh
	./scripts/restore.sh $(FILE)
