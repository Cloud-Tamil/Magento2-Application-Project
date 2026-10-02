# Local Development & Application Access Guide

Run the full Magento 2.4.7 stack locally with Docker Compose: application, web server, database, cache, search, message queue and a monitoring suite.

> **Local only.** Every credential, open port and security relaxation in this guide (2FA bypass, no-auth services, `guest/guest`) is for a developer machine. Never reuse any of it in staging or production. Production secrets live in **AWS Secrets Manager**.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Quickstart](#2-quickstart)
3. [Services](#3-services)
4. [Application Access & Credentials](#4-application-access--credentials)
5. [Command Cheatsheet](#5-command-cheatsheet)
6. [phpMyAdmin & Multi-Store Databases](#6-phpmyadmin--multi-store-databases)
7. [Security Notes for Local Setups](#7-security-notes-for-local-setups)
8. [Production Parity](#8-production-parity)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Prerequisites

- Docker Desktop or Docker Engine v24+ and Docker Compose v2.20+
- Git and Make
- **8 GB RAM minimum allocated to Docker** (16 GB recommended for full compilation and static content deployment)
- If the Magento codebase is not already vendored in the repo: Adobe Commerce / Magento Marketplace access keys configured in a gitignored `auth.json` so Composer can download packages
- Linux hosts only: `vm.max_map_count=262144` for OpenSearch (see [Troubleshooting](#9-troubleshooting))

---

## 2. Quickstart

### Step 1: Clone & configure

```bash
git clone <repo-url> magento2-devops
cd magento2-devops

# Copy the local environment template (includes monitoring and multi-store settings)
cp .env.example .env
```

`.env.example` is committed and must contain only non-secret development defaults. `.env` is gitignored and is where you override values.

### Step 2: Start all 9 services

```bash
# Build custom images (PHP 8.2-FPM, Prometheus, Grafana) and start the stack
make build
make up

# Check container status and health checks
make ps
```

### Step 3: Install Magento

```bash
make install
```

This runs `scripts/install-magento.sh`, which executes:

1. `bin/magento setup:install` with the Redis, OpenSearch, MySQL and RabbitMQ options
2. `bin/magento setup:di:compile`
3. `bin/magento setup:static-content:deploy -f en_US`
4. `bin/magento indexer:reindex`
5. `bin/magento cache:flush`

> For day-to-day development you can run Magento in **developer mode** (`bin/magento deploy:mode:set developer`). It generates code and static files on demand, so steps 2 and 3 are only needed to mimic production mode.

Open the storefront at <http://localhost:8080> and the admin at <http://localhost:8080/admin_control>.

---

## 3. Services

| # | Container | Image / Version | Port(s) | Role |
|---|---|---|---|---|
| 1 | `magento2-app` | PHP-FPM 8.2 | (internal 9000) | Magento application, working dir `/var/www/html` |
| 2 | `magento2-nginx` | Nginx 1.26 | 8080 | Web server |
| 3 | `magento2-mysql` | MySQL 8.0 | 3306 | Database |
| 4 | `magento2-phpmyadmin` | phpMyAdmin | 8081 | SQL admin console (multi-database) |
| 5 | `magento2-redis` | Redis 7.2 | 6379 | Cache, FPC, sessions |
| 6 | `magento2-opensearch` | OpenSearch 2.12 | 9200 / 9600 | Catalog search |
| 7 | `magento2-rabbitmq` | RabbitMQ 3.13 | 5672 / 15672 | Message queue and management UI |
| 8 | `magento2-prometheus` | Prometheus | 9090 | Metrics collection |
| 9 | `magento2-grafana` | Grafana | 3001 | Dashboards |

> **Container names vs service names:** the names above are container names. `docker compose` commands use the **service names** from `docker-compose.yml` (for example `magento`, `nginx`, `mysql`). The commands in this guide use those service names; adjust them if yours differ.

---

## 4. Application Access & Credentials

These are **local development defaults**, defined in `.env` / `.env.example`.

| Service | Access URL | Port | Default Credentials | Role |
|---|---|---|---|---|
| **Magento Storefront** | `http://localhost:8080` | 8080 | Guest / customer | Store served by Nginx 1.26 and PHP-FPM 8.2 |
| **Magento Admin** | `http://localhost:8080/admin_control` | 8080 | `devopsadmin` / `AdminPassword123!` | Admin portal; 2FA bypassed for local development only |
| **Grafana** | `http://localhost:3001` | 3001 | `admin` / `GrafanaAdminSecurePass123!` | Magento 2 analytics dashboards |
| **Prometheus** | `http://localhost:9090` | 9090 | No auth | Metrics collection |
| **phpMyAdmin** | `http://localhost:8081` | 8081 | `magento` / `magento_local_dev_pass123!` | Multi-database SQL console |
| **RabbitMQ Management** | `http://localhost:15672` | 15672 | `guest` / `guest` | Queues, messages, channels, consumers |
| **OpenSearch** | `http://localhost:9200` | 9200 | No auth (dev mode, security plugin disabled) | Search and aggregation API |
| **MySQL 8.0** | `localhost:3306` | 3306 | `magento` / `magento_local_dev_pass123!` | Database |
| **Redis** | `localhost:6379` | 6379 | No auth | Cache, FPC, sessions |

The admin path `admin_control` is the custom backend front name set during `setup:install`. The 2FA bypass is done by disabling the Magento two-factor modules locally; never do this on a shared or production environment.

---

## 5. Command Cheatsheet

### Service management

```bash
make up                       # start all services (detached)
docker compose ps             # container status and health checks
make monitoring-up            # start only Prometheus and Grafana
make monitoring-down          # stop the monitoring suite
docker compose logs -f magento nginx   # follow application and web logs
docker compose down           # stop and remove containers and networks (data volumes are kept)
```

> **Full reset:** `docker compose down -v` also deletes named volumes (database, Redis, OpenSearch data). You will need to run `make install` again.

### Shell and client access

```bash
# Magento CLI container as the unprivileged www-data user (UID 33)
docker compose exec -u www-data magento bash

# MySQL client (prompts for the password; avoids putting it in shell history)
docker compose exec mysql mysql -u magento -p magento2

# Redis CLI
docker compose exec redis redis-cli

# RabbitMQ health ping
docker compose exec rabbitmq rabbitmq-diagnostics -q ping

# OpenSearch cluster health
curl -s "http://localhost:9200/_cluster/health?pretty"

# Reload Prometheus configuration (requires Prometheus started with --web.enable-lifecycle)
curl -X POST http://localhost:9090/-/reload
```

### Magento maintenance

```bash
# Clear Magento cache types (preferred day to day)
docker compose exec -u www-data magento bin/magento cache:clean

# Flush the entire cache storage
docker compose exec -u www-data magento bin/magento cache:flush

# Reindex the catalog (OpenSearch)
docker compose exec -u www-data magento bin/magento indexer:reindex
docker compose exec -u www-data magento bin/magento indexer:status

# Compile dependency injection and deploy static content
docker compose exec -u www-data magento bin/magento setup:di:compile
docker compose exec -u www-data magento bin/magento setup:static-content:deploy -f en_US

# Run scheduled cron tasks once
docker compose exec -u www-data magento bin/magento cron:run

# Fix file ownership and permissions / run end-to-end health checks
./scripts/permissions.sh
./scripts/health-check.sh
```

---

## 6. phpMyAdmin & Multi-Store Databases

`docker/phpmyadmin/config.user.inc.php` exposes three database servers/schemas:

| Server | Store | Database |
|---|---|---|
| 1 | Main Retail Store | `magento2` |
| 2 | B2B Wholesale Store | `magento2_b2b` |
| 3 | EU International Store | `magento2_eu` |

Notes:

- Three **separate databases** means three separate Magento installations. A single Magento installation with multiple websites, stores and store views uses **one** database. Make sure this matches your intent.
- The `magento` MySQL user must have privileges on all three schemas, and the extra databases must be created (for example by an init script).

### Architectural mandate

- **Never** create custom tables in phpMyAdmin to store passwords, API keys or AWS credentials. phpMyAdmin is an SQL exploration tool only.
- Credentials are kept in `.env` (local, gitignored) and **AWS Secrets Manager** (production). `.env.example` is committed, so it holds non-secret development defaults only.
- phpMyAdmin must never be deployed to production.

---

## 7. Security Notes for Local Setups

- Docker publishes ports on **all host interfaces** by default, so MySQL, Redis (no auth), OpenSearch (no auth), RabbitMQ (`guest`) and phpMyAdmin are reachable by other machines on your network, including on shared Wi-Fi. Bind them to loopback in `docker-compose.yml`, for example:
  ```yaml
  ports:
    - "127.0.0.1:3306:3306"
  ```
- Do not pass passwords on the command line (`-p<password>`); they appear in process lists and shell history.
- Never commit `.env`, `auth.json` or any file with real credentials.

---

## 8. Production Parity

Keep local versions close to production to avoid surprises:

| Component | Local | Production target | Note |
|---|---|---|---|
| PHP | 8.2 | 8.2 | Match the image used on EKS |
| MySQL | 8.0 | RDS MySQL | MySQL 8.0 has reached end of standard community support; confirm the version your Magento release supports |
| Redis | 7.2 | ElastiCache | Redis OSS on ElastiCache tops out at 7.1; 7.2 is offered as Valkey. Pick one family for both |
| OpenSearch | 2.12 | Amazon OpenSearch Service 2.x | Use the same minor version where possible |
| RabbitMQ | 3.13 | Amazon MQ for RabbitMQ 3.13 | Match |
| Nginx | 1.26 | Same image | Match |

---

## 9. Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| OpenSearch exits or restarts | On Linux hosts run `sudo sysctl -w vm.max_map_count=262144`. Also cap the heap with `OPENSEARCH_JAVA_OPTS` (for example `-Xms512m -Xmx512m`) on small machines |
| Containers killed or very slow | Docker has less than 8 GB RAM; raise it in Docker Desktop settings |
| Port already in use | Another process uses 3306, 6379, 8080 and so on; change the published port in `.env` / compose file |
| 403/500 errors or cache write failures | Run `./scripts/permissions.sh` to fix ownership |
| Prometheus shows no Magento stack metrics | Scraping MySQL, Redis, PHP-FPM, Nginx and OpenSearch needs exporters (or built-in endpoints such as RabbitMQ's Prometheus plugin). The 9 listed containers contain none, so confirm the exporters exist in your compose setup |
| Search returns nothing | Run `indexer:status`, then `indexer:reindex`, and check `curl localhost:9200/_cluster/health` |
