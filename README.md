# Magento 2 Enterprise DevOps Platform & Infrastructure Suite

[![Magento 2.4.7](https://img.shields.io/badge/Magento-2.4.7-orange.svg)](https://experienceleague.adobe.com/)
[![PHP 8.2](https://img.shields.io/badge/PHP-8.2-blue.svg)](https://www.php.net/)
[![MySQL 8.0](https://img.shields.io/badge/MySQL-8.0-00758F.svg)](https://www.mysql.com/)
[![Kubernetes 1.30](https://img.shields.io/badge/Kubernetes-1.30-326ce5.svg)](https://kubernetes.io/)
[![Terraform 1.9+](https://img.shields.io/badge/Terraform-1.9+-844fba.svg)](https://www.terraform.io/)
[![Prometheus 2.52](https://img.shields.io/badge/Prometheus-2.52-E6522C.svg)](https://prometheus.io/)
[![Grafana 11.0](https://img.shields.io/badge/Grafana-11.0-F46800.svg)](https://grafana.com/)
[![AWS EKS](https://img.shields.io/badge/AWS-EKS-FF9900.svg)](https://aws.amazon.com/eks/)

A complete, production-grade DevOps engineering platform for **Adobe Commerce / Magento 2.4.7** running on **Docker (9 Services)**, **Kubernetes (Amazon EKS 1.30)**, and **AWS Infrastructure as Code (Terraform 1.9+)**.

---

## 🌟 Recent Modifications (Latest Release)

1. **Prometheus & Grafana Monitoring Suite (`monitoring/`)**:
   - `monitoring/prometheus/Dockerfile`: Prometheus 2.52 image with automated scrape targets for Nginx, PHP-FPM, MySQL, Redis, OpenSearch, and RabbitMQ.
   - `monitoring/prometheus/alerts.yml`: Production alert rules for 5xx spikes, PHP worker saturation, and memory limits.
   - `monitoring/grafana/Dockerfile`: Pre-configured Grafana 11.0 server with automated datasource and Magento 2 Production Analytics Dashboard.
2. **phpMyAdmin Multi-Store Database Administration**:
   - `docker/phpmyadmin/config.user.inc.php`: Configured for multi-store inspection (Server 1: `magento2`, Server 2: `magento2_b2b`, Server 3: `magento2_eu`).
   - Strict architectural isolation enforced: **Zero credentials stored in phpMyAdmin tables**.
3. **Multi-Store Credentials Centralization (`.env.example`)**:
   - Centralized Store 1 (Main), Store 2 (B2B Wholesale), and Store 3 (EU International) credentials, admin passwords, and API tokens.
4. **9-Service Orchestration (`docker-compose.yml`)**:
   - Added `prometheus` (port 9090) and `grafana` (port 3001) services with persistent volumes and healthchecks.
   - Added monitoring targets (`make monitoring-up`, `make monitoring-down`, `make monitoring-logs`) to `Makefile`.

---

## 1. Compatibility Matrix

| Component | Selected Version | Compatibility Status | Architectural Rationale & Official Requirements |
|---|---|---|---|
| **Magento** | `2.4.7-p3` / `2.4.7` | Official Enterprise Standard | Latest stable long-term release. Supports PHP 8.2 native optimizations, OpenSearch 2.x, and GraphQL caching. |
| **PHP** | `8.2.x` (Debian Bookworm) | Strictly Required | Official requirement for Magento 2.4.7. PHP 8.1 is deprecated/EOL; PHP 8.3 support is experimental in community modules. |
| **MySQL** | `8.0.36` (RDS & Docker) | Strictly Required | Official requirement. Configured with `binlog_format=ROW` and `transaction_isolation=READ-COMMITTED` to prevent deadlocks. |
| **Composer** | `2.7.x` | Strictly Required | Composer 2 is required for fast parallel resolution, memory optimization during `di:compile`, and lockfile v2. |
| **Nginx** | `1.26-alpine` | Recommended Web Server | Mainline stable release. Configured with 128k FastCGI buffers and gzip to prevent 502/504 errors on large payloads. |
| **Redis** | `7.2` (ElastiCache 7.1+) | Official Cache Backend | Sub-millisecond latency with `volatile-lru` eviction. DB 0: Default Cache, DB 1: Page Cache, DB 2: Sessions. |
| **OpenSearch** | `2.12` (AWS 2.11+) | Strictly Required | Required by Magento 2.4.7 for catalog search queries and layered navigation. Elasticsearch 7 is deprecated in 2.4.7. |
| **RabbitMQ** | `3.13` (Amazon MQ) | Official Message Broker | Erlang 26 compliant AMQP 0-9-1 broker for asynchronous queues, consumers, and email dispatching. |
| **Prometheus**| `2.52.0` | Metrics Engine | Time-series scraper with lifecycle API enabled for dynamic reloads without downtime. |
| **Grafana** | `11.0.0` | Analytics Portal | Visual dashboards pre-provisioned with e-commerce KPIs (Throughput, 5xx rate, PHP workers, Redis hit ratio). |
| **Kubernetes**| `1.30` | Target Orchestrator | Features HPA v2 autoscaling, Pod Disruption Budgets, and improved CSI volume handling. |
| **AWS EKS** | `1.30` | Production Engine | AWS managed control plane with OIDC IRSA and EBS/EFS CSI driver integration. |
| **Terraform** | `>= 1.9.0` | IaC Engine | Modern HCL with remote S3 backend state and DynamoDB distributed state locking. |
| **AWS Provider**| `~> 5.60` | Cloud Provider | Full support for EKS Pod Identity, EFS CSI, OpenSearch 2.x, and Secrets Manager. |

---

## 2. Core Architecture Rule: Credential & Secrets Isolation

> ⚠️ **ARCHITECTURAL MANDATE: NEVER USE phpMyAdmin FOR SECRETS STORAGE**
> - **phpMyAdmin** is strictly an interactive SQL administration tool for developers during local debugging. Storing application passwords, AWS credentials, or API tokens in phpMyAdmin tables is strictly prohibited.
> - **Local Development**: `.env` (derived from `.env.example`, gitignored).
> - **Kubernetes**: Kubernetes Secrets (`secret.example.yaml` / SealedSecrets / External Secrets Operator).
> - **Production AWS**: AWS Secrets Manager, with encryption via AWS KMS. Pods retrieve credentials dynamically via IAM Roles for Service Accounts (IRSA).
> - **Terraform**: Zero plaintext passwords in Git. Automatically generated via `random_password` and stored into AWS Secrets Manager.

---

## 3. Complete Application Access & Credentials Matrix

| Service | Access URL | Host Port | Default Credentials | Description / Role |
|---|---|---|---|---|
| **Magento 2 Storefront** | `http://localhost:8080` | 8080 | Customer / Guest | Main production storefront served by Nginx 1.26 with FastCGI proxying to PHP-FPM 8.2 |
| **Magento Admin Panel** | `http://localhost:8080/admin_control` | 8080 | User: `devopsadmin`<br>Pass: `AdminPassword123!` | Management portal with 2FA bypass for local dev |
| **Grafana Dashboard** | `http://localhost:3001` | 3001 | User: `admin`<br>Pass: `GrafanaAdminSecurePass123!` | Live throughput, 5xx rate, PHP-FPM workers & cache hits |
| **Prometheus Server** | `http://localhost:9090` | 9090 | No Auth | Metric scraper & alerting engine |
| **phpMyAdmin Console** | `http://localhost:8081` | 8081 | User: `magento`<br>Pass: `magento_local_dev_pass123!` | Multi-store DB admin (Store 1, Store 2, Store 3) |
| **RabbitMQ Console** | `http://localhost:15672` | 15672 | User: `guest`<br>Pass: `guest` | Queue metrics, consumers & message channels |
| **OpenSearch REST API**| `http://localhost:9200` | 9200 | No Auth (Dev mode) | Catalog search queries & shard health API |
| **MySQL Database Port**| `localhost:3306` | 3306 | User: `magento`<br>Pass: `magento_local_dev_pass123!` | Primary relational database port |
| **Redis Cache Port** | `localhost:6379` | 6379 | No Auth (Local) | In-memory cache & session persistence |

---

## 4. Multi-Store Architecture Details

The platform supports multiple Magento stores with isolated database contexts or shared schemas:
- **Store 1 (Main Retail)**: `STORE_MAIN_CODE=default` (`http://localhost:8080`)
- **Store 2 (B2B Wholesale)**: `STORE_B2B_CODE=b2b_store` (`http://b2b.localhost:8080`)
- **Store 3 (EU International)**: `STORE_EU_CODE=eu_store` (`http://eu.localhost:8080`, EUR currency)

All store configurations and API integration tokens are managed in `.env` locally and AWS Secrets Manager in cloud production.

---

## 5. High-Level Architecture Topology

```
Developer Workstation
         |
      (Git Push)
         v
GitHub Enterprise Repository
         |
GitHub Actions CI/CD Pipeline (Lint -> Trivy Vulnerability Scan -> Multi-stage Build)
         |
    (Docker Push)
         v
Amazon ECR (Encrypted Container Registry: PHP-FPM 8.2 & Nginx 1.26)
         |
    (Helm Rollout)
         v
+-----------------------------------------------------------------------------------+
| AWS EKS Cluster (Kubernetes 1.30 - Private Worker Subnets across 3 AZs)            |
|                                                                                   |
|           [ AWS Application Load Balancer (ALB) + ACM TLS Certificate ]           |
|                                     |                                             |
|                                 (NodePort)                                        |
|                                     v                                             |
|                  [ Ingress / AWS Load Balancer Controller ]                       |
|                                     |                                             |
|                     +---------------+---------------+                             |
|                     |                               |                             |
|                     v                               v                             |
|           [ Magento Web Pod 1 ]           [ Magento Web Pod 2 ] ... [ Pod N ]     |
|             ├── Nginx 1.26                  ├── Nginx 1.26                        |
|             └── PHP-FPM 8.2                 └── PHP-FPM 8.2                       |
|             ├── Mount: AWS EFS Media        ├── Mount: AWS EFS Media              |
|             └── IRSA ServiceAccount         └── IRSA ServiceAccount               |
|                                                                                   |
|     [ HPA: Horizontal Pod Autoscaler (Scale 3 -> 15 Pods on CPU 70% / Mem 80%) ]  |
|     [ CronJob: bin/magento cron:run (Every 60s, Concurrency: Forbid) ]            |
+-----------------------------------------------------------------------------------+
           |                     |                      |                     |
           v                     v                      v                     v
+--------------------+ +--------------------+ +--------------------+ +--------------+
|   AWS RDS MySQL    | |  ElastiCache Redis | |   AWS OpenSearch   | |  Amazon MQ   |
|   8.0 (Multi-AZ)   | |  7.1 (Cache/Sess)  | |   Domain (3 AZs)   | |  (RabbitMQ)  |
|    (Port 3306)     | |    (Port 6379)     | |    (Port 443)      | | (Port 5671)  |
+--------------------+ +--------------------+ +--------------------+ +--------------+
           ^                     ^                      ^                     ^
           |                     |                      |                     |
           +---------------------+----------------------+---------------------+
                                 |
                 [ AWS Secrets Manager (KMS Vault) ]
                                 |
                 [ Terraform Remote State (S3 + DynamoDB) ]
```

---

## 6. Project Directory Layout

```
magento2-devops/
├── README.md                               # Complete platform documentation & runbooks
├── .gitignore                              # Git exclusion rules (.env, *.tfstate, vendor)
├── .env.example                            # Local dev environment template & store credentials
├── docker-compose.yml                      # 9-service local stack (Magento, Nginx, MySQL, PMA, Redis, OS, RMQ, Prom, Grafana)
├── Makefile                                # Fast developer command shortcuts
│
├── monitoring/
│   ├── prometheus/
│   │   ├── Dockerfile                      # Custom Prometheus 2.52 image
│   │   ├── prometheus.yml                  # Scrape configs for 6 infrastructure services
│   │   └── alerts.yml                      # Alert rules for 5xx errors, worker exhaustion
│   └── grafana/
│       ├── Dockerfile                      # Custom Grafana 11.0 image
│       ├── provisioning/
│       │   ├── datasources/datasources.yml # Automated Prometheus connection
│       │   └── dashboards/dashboards.yml   # Automated dashboard provider
│       └── dashboards/
│           └── magento2-overview.json      # Pre-configured Magento 2 Production Analytics
│
├── docker/
│   ├── magento/
│   │   ├── Dockerfile                      # Multi-stage production PHP 8.2-FPM image
│   │   ├── php.ini                         # Magento production PHP configuration
│   │   ├── opcache.ini                     # High-performance OPcache & JIT tuning
│   │   └── www.conf                        # Tuned PHP-FPM process manager pool
│   ├── nginx/default.conf                  # FastCGI proxy, /pub routing, gzip & security
│   ├── mysql/my.cnf                        # MySQL 8.0 buffer pool & binary log settings
│   ├── redis/redis.conf                    # In-memory persistence & LRU eviction
│   ├── opensearch/opensearch.yml           # OpenSearch 2.12 cluster config
│   ├── rabbitmq/rabbitmq.conf              # AMQP listeners & watermark thresholds
│   └── phpmyadmin/config.user.inc.php      # Multi-store database management configuration
│
├── scripts/
│   ├── install-magento.sh                  # Non-interactive CLI setup installer
│   ├── setup-local.sh                      # Local stack bootstrapper
│   ├── permissions.sh                      # File permission & ownership fixer
│   ├── health-check.sh                     # Service ping & connectivity verifier
│   ├── backup.sh                           # MySQL dump & media asset archiver
│   └── restore.sh                          # Transactional database & media restore
│
├── kubernetes/
│   ├── namespace.yaml                      # 'magento' namespace with Pod Security baseline
│   ├── configmap.yaml                      # Non-sensitive endpoints & app environment
│   ├── secret.example.yaml                 # Sensitive credentials schema
│   ├── deployment.yaml                     # Dual-container Pod (Nginx + PHP-FPM)
│   ├── service.yaml                        # NodePort service routing traffic from ALB
│   ├── ingress.yaml                        # AWS Load Balancer Controller Ingress
│   ├── hpa.yaml                            # Horizontal Pod Autoscaler (3-15 replicas)
│   ├── pdb.yaml                            # Pod Disruption Budget (minAvailable: 2)
│   ├── serviceaccount.yaml                 # IRSA ServiceAccount for Secrets Manager
│   ├── config/magento-config.yaml          # Nginx server block mounted ConfigMap
│   ├── storage/storageclass.yaml           # EBS GP3 and EFS CSI storage classes
│   ├── storage/pvc.yaml                    # ReadWriteMany shared media PVC
│   ├── cronjob.yaml                        # bin/magento cron:run every 60s
│   └── jobs/                               # Maintenance jobs (upgrade, reindex, cache-flush)
│
├── helm/
│   └── magento/
│       ├── Chart.yaml                      # Helm chart metadata (v1.0.0)
│       ├── values.yaml                     # Base defaults
│       ├── values-dev.yaml                 # Cost-optimized development overrides
│       ├── values-staging.yaml             # Staging pre-production mirror
│       ├── values-prod.yaml                # 5-30 autoscaling replicas & high IOPS
│       └── templates/                      # Parameterized Kubernetes templates
│
├── terraform/
│   ├── environments/
│   │   ├── dev/                            # Single NAT, spot instances, cost-optimized
│   │   ├── staging/                        # Multi-AZ mirror of production
│   │   └── prod/                           # Multi-AZ across 3 AZs, immutable ECR
│   └── modules/
│       ├── vpc/                            # Multi-AZ subnets (Public, App, DB)
│       ├── security-groups/                # Strict least-privilege firewalls
│       ├── iam/                            # EKS control plane, node & IRSA roles
│       ├── ecr/                            # Encrypted repositories & lifecycle policies
│       ├── eks/                            # Managed EKS 1.30 & node groups
│       ├── rds/                            # Private Multi-AZ MySQL 8.0
│       ├── redis/                          # ElastiCache Redis 7.1 replication group
│       ├── opensearch/                     # 3-Master + 3-Data node search cluster
│       ├── mq/                             # Amazon MQ RabbitMQ broker
│       ├── alb/                            # AWS Load Balancer Controller IAM
│       ├── route53/                        # ACM certificates & DNS records
│       ├── secrets/                        # AWS Secrets Manager password generator
│       ├── cloudwatch/                     # Log groups & metric alarms
│       └── s3-state/                       # S3 remote state & DynamoDB lock table
│
├── .github/workflows/
│   └── deploy.yml                          # Lint, Trivy scan, Docker build, ECR & EKS
│
└── docs/
    ├── architecture.md                     # System architecture & storage rules
    ├── local-development.md                # Docker Compose & phpMyAdmin guide
    ├── kubernetes.md                       # Manifests & deployment sequence
    ├── aws.md                              # AWS cloud architecture specifications
    ├── terraform.md                        # IaC module usage & state locking
    ├── security.md                         # Hardening, non-root, and least-privilege
    ├── monitoring.md                       # CloudWatch alarms & metrics matrix
    ├── backup-restore.md                   # RPO/RTO targets & snapshot playbooks
    └── troubleshooting.md                  # Symptom, Cause, Diagnosis, Fix index
```

---

## 7. Useful Commands Cheatsheet

### 1. Quickstart (Start All 9 Services)
```bash
# 1. Prepare environment variables
cp .env.example .env

# 2. Build and start all 9 microservices in detached mode
make build
make up

# 3. Verify running status and healthchecks of all 9 containers
make ps

# 4. Run automated Magento 2 setup installer
make install
```

### 2. Service Management & Monitoring
```bash
# Start only the monitoring stack (Prometheus & Grafana)
make monitoring-up

# Stop the monitoring stack
make monitoring-down

# Follow Prometheus and Grafana logs
make monitoring-logs

# Hot reload Prometheus configuration dynamically
curl -X POST http://localhost:9090/-/reload

# Check Grafana health API
curl -u admin:GrafanaAdminSecurePass123! http://localhost:3001/api/health
```

### 3. CLI Terminal Access Commands
```bash
# Enter Magento CLI container as unprivileged www-data user (UID 33)
docker compose exec -it -u www-data magento bash

# Connect to MySQL interactive command-line client
docker compose exec mysql mysql -u magento -pmagento_local_dev_pass123! magento2

# Connect to Redis interactive CLI
docker compose exec redis redis-cli

# Test RabbitMQ broker health ping
docker compose exec rabbitmq rabbitmq-diagnostics -q ping

# Check OpenSearch cluster health status
curl -s "http://localhost:9200/_cluster/health?pretty"
```

### 4. Magento Maintenance Commands (`bin/magento`)
```bash
# Flush Redis cache storage (default, page_cache, and session)
docker compose exec -u www-data magento bin/magento cache:flush

# Clean outdated cache types
docker compose exec -u www-data magento bin/magento cache:clean

# Reindex OpenSearch catalog
docker compose exec -u www-data magento bin/magento indexer:reindex

# Check status of all 9 Magento indexers
docker compose exec -u www-data magento bin/magento indexer:status

# Run Dependency Injection compilation (di:compile)
docker compose exec -u www-data magento bin/magento setup:di:compile

# Deploy static frontend content for en_US
docker compose exec -u www-data magento bin/magento setup:static-content:deploy -f en_US

# Upgrade Magento database schema & modules
docker compose exec -u www-data magento bin/magento setup:upgrade --keep-generated

# Run scheduled cron tasks & queue consumers
docker compose exec -u www-data magento bin/magento cron:run

# Verify file ownership and permissions
./scripts/permissions.sh

# Run end-to-end stack health checks
./scripts/health-check.sh
```

### 5. Kubernetes & AWS EKS Commands
```bash
# Authenticate local kubectl with target EKS cluster
aws eks update-kubeconfig --region us-east-1 --name magento-prod-eks

# List all running Magento pods with IPs and host nodes
kubectl get pods -n magento -o wide

# Check Ingress & AWS ALB Hostname
kubectl get ingress -n magento

# Monitor Horizontal Pod Autoscaler (HPA) real-time scaling
kubectl get hpa -n magento -w

# Perform zero-downtime rolling restart of web pods
kubectl rollout restart deployment/magento-web -n magento

# Stream PHP-FPM application logs across all active pods
kubectl logs -n magento -l app.kubernetes.io/component=web-frontend -c php-fpm -f --tail=100
```

### 6. Terraform AWS Infrastructure Commands
```bash
# Provision remote state S3 bucket & DynamoDB distributed locking table
cd terraform/modules/s3-state && terraform init && terraform apply -var="account_id=123456789012"

# Initialize environment backend (Dev or Prod)
cd terraform/environments/dev && terraform init

# Validate syntax, variable types, and resource schemas
terraform fmt -check && terraform validate

# Generate infrastructure execution plan
terraform plan -out=tfplan

# Apply infrastructure plan in AWS
terraform apply tfplan

# Inspect output connection strings and ARNs
terraform output
```

### 7. Backup, Restore & Disaster Recovery Commands
```bash
# Execute full database and media backup
chmod +x scripts/backup.sh && ./scripts/backup.sh

# Restore database and media from a specific backup archive
chmod +x scripts/restore.sh && ./scripts/restore.sh ./backups/magento_db_2026-10-02.sql.gz
```

---

## 8. Diagnostic & Troubleshooting Reference

| Symptom | Probable Cause | Diagnosis Command | Verified Remediation |
|---|---|---|---|
| **HTTP 502 Bad Gateway** | PHP-FPM process pool exhausted or hit `memory_limit`. | `docker compose logs --tail=50 magento \| grep -E "pm.max_children\|Fatal"` | Increase `pm.max_children = 50` in `www.conf` and set `memory_limit = 2048M` in `php.ini`. |
| **Pod in `CrashLoopBackOff`** | `startupProbe` failed or missing DB credentials in Kubernetes Secret. | `kubectl describe pod -l app.kubernetes.io/component=web-frontend -n magento` | Ensure RDS security group permits port 3306 from EKS worker node security group. |
| **`ImagePullBackOff`** | EKS worker node IAM role lacks ECR read policy or image tag missing. | `kubectl describe pod -n magento \| grep -A 5 -i "Failed to pull image"` | Attach `AmazonEC2ContainerRegistryReadOnly` policy to the node group IAM role. |
| **Terraform State Lock Failure** | Previous `terraform apply` aborted abnormally in CI. | `aws dynamodb scan --table-name magento2-devops-terraform-locks` | Release lock using the reported ID: `terraform force-unlock <LOCK-ID>`. |
| **OpenSearch Connection Refused** | Host `vm.max_map_count` too low or OpenSearch not ready. | `curl -i http://localhost:9200/_cluster/health` | Set `sudo sysctl -w vm.max_map_count=262144`, restart container, and run `make reindex`. |
| **Port Conflict on 3306 / 8080** | Local MySQL service or another container occupying port. | `sudo lsof -i :3306 \|\| sudo netstat -tulpn \| grep 3306` | Stop host service (`sudo systemctl stop mysql`) or adjust `WEB_PORT` in `.env`. |
