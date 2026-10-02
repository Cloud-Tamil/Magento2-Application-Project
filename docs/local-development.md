# Local Development & Application Access Guide

## Prerequisites

- Docker Desktop or Docker Engine v24+ & Docker Compose v2.20+
- 8GB RAM minimum allocated to Docker (16GB recommended for full compilation)
- Git & Make

---

## 1. Step-by-Step Quickstart

### Step 1: Clone & Configure
```bash
git clone <repo-url> magento2-devops
cd magento2-devops

# Copy local environment template (includes monitoring & multi-store credentials)
cp .env.example .env
```

### Step 2: Start All 9 Docker Services (Full Stack + Monitoring)
```bash
# Build custom images (PHP 8.2-FPM, Prometheus, Grafana) and spin up stack
make build
make up

# Check status and healthcheck states of all 9 containers
make ps
```

All 9 containers will initialize:
1. `magento2-app`: PHP-FPM 8.2 (working dir `/var/www/html`)
2. `magento2-nginx`: Nginx Web Server on port 8080
3. `magento2-mysql`: MySQL 8.0 on port 3306
4. `magento2-phpmyadmin`: phpMyAdmin Multi-Store Console on port 8081
5. `magento2-redis`: Redis 7.2 on port 6379
6. `magento2-opensearch`: OpenSearch 2.12 on ports 9200/9600
7. `magento2-rabbitmq`: RabbitMQ 3.13 on ports 5672/15672
8. `magento2-prometheus`: Prometheus Metrics Collector on port 9090
9. `magento2-grafana`: Grafana Visual Analytics on port 3001

### Step 3: Run Automated Magento Installation
```bash
make install
```
This runs `scripts/install-magento.sh`, executing:
- `bin/magento setup:install` with all Redis, OpenSearch, MySQL, and RabbitMQ flags
- `bin/magento setup:di:compile`
- `bin/magento setup:static-content:deploy -f en_US`
- `bin/magento indexer:reindex`
- `bin/magento cache:flush`

---

## 2. Complete Application Access & Credentials Matrix

| Service | Access URL | Port | Default Credentials | Description / Role |
|---|---|---|---|---|
| **Magento Storefront** | `http://localhost:8080` | 8080 | Guest / Customer | Main store served by Nginx 1.26 & PHP-FPM 8.2 |
| **Magento Admin Panel** | `http://localhost:8080/admin_control` | 8080 | User: `devopsadmin`<br>Pass: `AdminPassword123!` | Management portal with 2FA bypass for local dev |
| **Grafana Dashboard** | `http://localhost:3001` | 3001 | User: `admin`<br>Pass: `GrafanaAdminSecurePass123!` | Pre-configured Magento 2 Production Analytics |
| **Prometheus Server** | `http://localhost:9090` | 9090 | No Auth | Scrapes Nginx, PHP-FPM, MySQL, Redis, OpenSearch & RabbitMQ |
| **phpMyAdmin Console** | `http://localhost:8081` | 8081 | User: `magento`<br>Pass: `magento_local_dev_pass123!` | Multi-store DB admin (Store 1, Store 2, Store 3) |
| **RabbitMQ Management**| `http://localhost:15672` | 15672| User: `guest`<br>Pass: `guest` | Queue depths, messages, channels & consumers |
| **OpenSearch Engine** | `http://localhost:9200` | 9200 | No Auth (Dev mode) | Full-text catalog search & aggregation API |
| **MySQL 8.0 Port** | `localhost:3306` | 3306 | User: `magento`<br>Pass: `magento_local_dev_pass123!` | Master database port |
| **Redis Cache Port** | `localhost:6379` | 6379 | No Auth (Local) | In-memory cache, FPC, and session store |

---

## 3. Useful Commands Cheatsheet

### Service Management Commands
```bash
# Start all 9 services in detached mode
docker compose up -d

# Start only monitoring suite (Prometheus & Grafana)
make monitoring-up

# Stop monitoring suite
make monitoring-down

# View container status & health checks
docker compose ps

# Follow logs from Magento and Nginx
docker compose logs -f magento nginx

# Stop and remove all containers and networks
docker compose down
```

### CLI Terminal Access Commands
```bash
# Enter Magento CLI container as unprivileged www-data user (UID 33)
docker compose exec -it -u www-data magento bash

# Connect to MySQL interactive command-line client
docker compose exec mysql mysql -u magento -pmagento_local_dev_pass123! magento2

# Connect to Redis CLI
docker compose exec redis redis-cli

# Test RabbitMQ broker health ping
docker compose exec rabbitmq rabbitmq-diagnostics -q ping

# Check OpenSearch cluster health status
curl -s "http://localhost:9200/_cluster/health?pretty"

# Hot reload Prometheus configuration dynamically
curl -X POST http://localhost:9090/-/reload
```

### Magento Maintenance Commands
```bash
# Flush Redis cache storage
docker compose exec -u www-data magento bin/magento cache:flush

# Clean cache types
docker compose exec -u www-data magento bin/magento cache:clean

# Reindex OpenSearch catalog
docker compose exec -u www-data magento bin/magento indexer:reindex

# Check status of indexers
docker compose exec -u www-data magento bin/magento indexer:status

# Run Dependency Injection compilation
docker compose exec -u www-data magento bin/magento setup:di:compile

# Deploy static frontend content
docker compose exec -u www-data magento bin/magento setup:static-content:deploy -f en_US

# Run scheduled cron tasks
docker compose exec -u www-data magento bin/magento cron:run

# Verify file ownership and permissions
./scripts/permissions.sh

# Run end-to-end stack health checks
./scripts/health-check.sh
```

---

## 4. phpMyAdmin Multi-Store Database Administration

`docker/phpmyadmin/config.user.inc.php` provides multi-store database administration for 3 store instances:
- **Server 1**: Main Retail Store (`magento2`)
- **Server 2**: B2B Wholesale Store (`magento2_b2b`)
- **Server 3**: EU International Store (`magento2_eu`)

### ⚠️ Strict Architectural Mandate
- **NEVER** create custom tables in phpMyAdmin to store passwords, API keys, or AWS credentials!
- phpMyAdmin is strictly an SQL query exploration tool.
- All store credentials are maintained securely in `.env.example` / `.env` (local) and **AWS Secrets Manager** (production).
