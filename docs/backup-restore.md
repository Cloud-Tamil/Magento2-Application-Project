# Magento 2 / Adobe Commerce on AWS: Enterprise DevOps Architecture

Reference architecture for running **Adobe Commerce / Magento Open Source 2.4.7** on **Amazon EKS** with AWS managed services. It provides autoscaling, zero-downtime rolling deployments, isolated private networking, multi-AZ resilience and centralised observability.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [AWS Service Mapping](#2-aws-service-mapping)
3. [Network Design](#3-network-design)
4. [Application Workloads on EKS](#4-application-workloads-on-eks)
5. [Data, Cache & Persistence](#5-data-cache--persistence)
6. [Secrets Management](#6-secrets-management)
7. [Security](#7-security)
8. [Monitoring & Alerting](#8-monitoring--alerting)
9. [CI/CD & Zero-Downtime Deployments](#9-cicd--zero-downtime-deployments)
10. [Deployment Order](#10-deployment-order)
11. [Operational Notes](#11-operational-notes)
12. [Backup & Disaster Recovery](#12-backup--disaster-recovery)
13. [Version & Support Checklist](#13-version--support-checklist)

---

## 1. System Overview

```mermaid
flowchart TB
    User([Users]) --> CDN[CDN / Cloudflare<br/>optional]
    CDN --> R53[Route 53]
    R53 --> ALB[Application Load Balancer<br/>HTTPS 443, ACM TLS 1.2+]

    subgraph VPC["VPC - 3 Availability Zones"]
        subgraph Public["Public Subnets"]
            ALB
            NAT[NAT Gateways<br/>one per AZ]
        end

        subgraph App["Private App Subnets"]
            subgraph EKS["Amazon EKS"]
                ING[Ingress<br/>AWS Load Balancer Controller]
                SVC[magento Service<br/>ClusterIP]
                P1[Magento Pod 1<br/>Nginx + PHP-FPM]
                P2[Magento Pod 2<br/>Nginx + PHP-FPM]
                PN[Magento Pod N]
                CRON[CronJob<br/>magento cron:run]
                CONS[Queue consumer<br/>Deployment]
                HPA[HPA<br/>CPU 70% / Mem 80%]
            end
            EFS[(Amazon EFS<br/>pub/media)]
        end

        subgraph DB["Private DB Subnets"]
            RDS[(RDS MySQL<br/>Multi-AZ, 3306)]
            REDIS[(ElastiCache Redis<br/>Multi-AZ, 6379)]
            OS[(OpenSearch<br/>3 master + 3 data, 443)]
            MQ[(Amazon MQ RabbitMQ<br/>5671)]
        end
    end

    ALB --> ING --> SVC
    SVC --> P1 & P2 & PN
    HPA -. scales .-> P1
    P1 & P2 & PN & CRON & CONS --> RDS
    P1 & P2 & PN & CRON & CONS --> REDIS
    P1 & P2 & PN & CRON & CONS --> OS
    P1 & P2 & PN & CRON & CONS --> MQ
    P1 & P2 & PN --> EFS
    EKS -. IRSA / Pod Identity .-> SM[AWS Secrets Manager<br/>+ KMS]
    EKS -. pull images .-> ECR[Amazon ECR]
    EKS -. logs / metrics .-> CW[CloudWatch]
    App --> NAT
```

Key design choices:

- Each Magento pod runs **Nginx and PHP-FPM containers** side by side and mounts shared media from EFS.
- The ALB sends traffic **directly to pod IPs** (`alb.ingress.kubernetes.io/target-type: ip`) through a `ClusterIP` Service. This avoids the extra NodePort hop and gives more accurate health checks.
- Static assets (`pub/static`) and compiled code are **baked into immutable Docker images** in CI/CD, so there is no runtime NFS latency for them.
- Cron and queue consumers run as separate workloads, not inside web pods.

---

## 2. AWS Service Mapping

| Component | AWS Managed Service | Configuration Details |
|---|---|---|
| Networking | Amazon VPC | 3 AZs; public, private-app and private-DB subnets; one NAT Gateway per AZ |
| Container Orchestration | Amazon EKS | Managed Node Groups in private subnets; IRSA or EKS Pod Identity; EBS CSI, EFS CSI, CoreDNS, VPC CNI, kube-proxy add-ons; Kubernetes Secrets envelope encryption with KMS; use a currently supported version |
| Ingress / Load Balancing | Application Load Balancer | Provisioned by AWS Load Balancer Controller; HTTP-to-HTTPS redirect; ACM certificate; TLS 1.2+ policy |
| Container Registry | Amazon ECR | Private repos, KMS encryption, scan on push, lifecycle rules, immutable tags |
| Database | Amazon RDS for MySQL | Multi-AZ synchronous standby, private DB subnets, automated backups, Performance Insights / Database Insights, storage autoscaling, KMS encryption |
| Cache & Sessions | Amazon ElastiCache for Redis | Multi-AZ replication groups with automatic failover, **cluster mode disabled**, in-transit and at-rest encryption |
| Catalog Search | Amazon OpenSearch Service | VPC deployment, zone awareness across 3 AZs, 3 dedicated master nodes, 3 data nodes |
| Message Queuing | Amazon MQ for RabbitMQ | Multi-AZ **cluster** deployment (3 nodes) in production; single-instance for non-production; AMQPS on port 5671 |
| Secrets Vault | AWS Secrets Manager + KMS | No plaintext secrets in Git; random passwords; rotation where supported |
| Shared Media Storage | Amazon EFS | EFS CSI driver, `ReadWriteMany` volume for `pub/media`; mount targets in every app AZ |
| Monitoring & Logs | Amazon CloudWatch | Container Insights, structured JSON logs, alarms |
| DNS & Certificates | Route 53 & ACM | Public hosted zone; ACM certificates with DNS validation |
| CDN / Edge (optional) | CloudFront or Cloudflare | Caches static and media assets; WAF and bot protection |

---

## 3. Network Design

| Tier | Subnets | Contains |
|---|---|---|
| Public | 3 (one per AZ) | ALB, NAT Gateways |
| Private App | 3 (one per AZ) | EKS worker nodes, EFS mount targets |
| Private DB | 3 (one per AZ) | RDS, ElastiCache, OpenSearch, Amazon MQ (no route to the internet) |

- Tag public subnets `kubernetes.io/role/elb = 1` and private app subnets `kubernetes.io/role/internal-elb = 1`.
- Consider VPC endpoints (S3 gateway; interface endpoints for ECR, STS, Secrets Manager, CloudWatch Logs) to reduce NAT cost and keep traffic on the AWS network.
- If a CDN such as Cloudflare fronts the ALB, restrict ALB ingress to the CDN's IP ranges (or use a secret origin header) and configure Magento/Nginx to trust the forwarded client IP.

---

## 4. Application Workloads on EKS

| Workload | Kind | Notes |
|---|---|---|
| Magento web | Deployment (Nginx + PHP-FPM) | Rolling updates, readiness/liveness probes, `preStop` delay, PodDisruptionBudget, topology spread across AZs |
| Autoscaling | HorizontalPodAutoscaler | Target CPU 70%; memory (80%) can be added but is a weak signal for PHP-FPM, so CPU or request-based metrics are preferred |
| Scheduled tasks | CronJob | `magento cron:run` every minute, `concurrencyPolicy: Forbid`, bounded history, resource limits |
| Async consumers | Deployment | Runs `bin/magento queue:consumers:start <name>` workers against RabbitMQ; scale independently of web |
| Schema upgrades | Job (pre-deploy) | Runs `setup:upgrade` once per release, not from every pod at startup |
| Media | PVC (EFS, RWX) | Mounted at `pub/media` in web, cron and consumer pods |

Pods use a dedicated ServiceAccount bound to an IAM role (IRSA or Pod Identity) for Secrets Manager access.

---

## 5. Data, Cache & Persistence

### Relational database
- Amazon RDS MySQL in private DB subnets with Multi-AZ synchronous standby replication.
- Automated backups, Performance Insights / Database Insights, and storage autoscaling.
- Consider a read replica for reporting or split-database setups.

### Redis cache and sessions
Use **cluster-mode-disabled** replication groups (Magento does not support Redis Cluster mode), with automatic failover across AZs.

| Purpose | Redis DB | Recommended eviction policy |
|---|---|---|
| Default cache | 0 | `allkeys-lru` |
| Full Page Cache (FPC) | 1 | `allkeys-lru` |
| PHP sessions | 2 | `noeviction` (or `volatile-lru`) |

> **Important:** eviction policy is set per Redis instance (parameter group), not per logical database. A single `allkeys-lru` instance can evict live customer sessions and log users out or empty carts under memory pressure. For production, use **two replication groups**: one for cache and FPC (`allkeys-lru`) and a separate one for sessions (`noeviction`, sized with headroom and monitored on memory).

### Search
Amazon OpenSearch Service, VPC-deployed, zone-aware across 3 AZs, with 3 dedicated master nodes and 3 data nodes. Use a version supported by your Magento release.

### Messaging
Amazon MQ for RabbitMQ as a multi-AZ cluster. Connect over TLS (port 5671) and set `ssl` options in Magento's queue configuration.

### Shared media
`pub/media` (product images, catalog media, uploads) lives on Amazon EFS via the EFS CSI driver (`ReadWriteMany`). Use General Purpose performance mode and Elastic throughput unless benchmarking shows otherwise. Serve media through a CDN to limit EFS reads.

---

## 6. Secrets Management

- **phpMyAdmin is never a secrets vault.** It is an interactive SQL tool for local debugging only. Never store application passwords, AWS credentials or API tokens in database tables through it, and do not expose it in production.
- **Local development:** `.env` derived from `.env.example`, gitignored.
- **Kubernetes:** secrets are injected as environment variables (`envFrom`) or mounted files. Standard Kubernetes Secrets are only base64-encoded, so enable **EKS envelope encryption with KMS** and restrict RBAC access to them.
- **Production AWS:** AWS Secrets Manager encrypted with KMS. Pods fetch values through IRSA / Pod Identity, via the Secrets Store CSI Driver (AWS provider) or External Secrets Operator.
- **Terraform:** no plaintext passwords in Git. Passwords come from `random_password` and are stored in Secrets Manager immediately. Note that **generated values also exist in Terraform state**, so keep state in an encrypted, access-controlled backend (S3 with KMS and locking). For RDS, prefer `manage_master_user_password = true` so AWS creates and rotates the master secret and it never enters state.

---

## 7. Security

### Private worker nodes
All EKS worker nodes run in private app subnets. SSH and public IPs are disabled; use AWS Systems Manager Session Manager if node access is needed.

### Security group ingress
Data services accept traffic only from the EKS worker nodes security group (`eks_nodes_sg`):

| Service | Port |
|---|---|
| RDS MySQL | 3306 |
| ElastiCache Redis | 6379 |
| OpenSearch (HTTPS) | 443 |
| Amazon MQ RabbitMQ (AMQPS) | 5671 |
| EFS (NFS) | 2049 |

### Least-privilege IAM
IRSA or Pod Identity provides short-lived STS credentials to pods, with no AWS access keys in containers. Scope each role to the specific secret ARNs (and S3 prefixes, if S3 is used).

### Encryption
- **At rest:** KMS for ECR, RDS, EFS, ElastiCache, OpenSearch, Amazon MQ, EBS and Kubernetes Secrets.
- **In transit:** TLS 1.2+ on the ALB, Redis, OpenSearch, RabbitMQ and RDS connections.

### Admin hardening
Restrict the Magento admin URL (custom path, IP allow-list or WAF rule), enable 2FA, and consider AWS WAF on the ALB.

---

## 8. Monitoring & Alerting

- Container Insights for cluster, node and pod metrics.
- Structured JSON logs from Nginx, PHP-FPM and Magento to CloudWatch Logs.
- Baseline alarms:

| Alarm | Threshold |
|---|---|
| RDS `CPUUtilization` | > 80% |
| ElastiCache `DatabaseMemoryUsagePercentage` | > 85% |

- Recommended additions: RDS free storage and connections, Redis evictions (especially on the sessions group), OpenSearch cluster status and JVM pressure, RabbitMQ queue depth and memory, ALB 5xx rate and unhealthy targets, CronJob failures, HPA at max replicas.

---

## 9. CI/CD & Zero-Downtime Deployments

1. Build the image in CI: `composer install --no-dev`, `setup:di:compile`, `setup:static-content:deploy` (all locales/themes), so `pub/static` and `generated/` ship inside the image.
2. Scan and push to ECR with an immutable tag (commit SHA).
3. Run the schema upgrade Job (`setup:upgrade --keep-generated`) once, before rolling out web pods. Keep schema changes backward-compatible so old and new pods can run together during the rollout.
4. Roll out with `RollingUpdate` (`maxUnavailable: 0`), readiness probes and a PodDisruptionBudget.
5. Flush/warm caches as required and verify health checks.
6. Roll back with `kubectl rollout undo` (database changes need their own rollback plan).

---

## 10. Deployment Order

1. Networking: VPC, subnets, routes, NAT Gateways, security groups.
2. KMS keys and Secrets Manager secrets.
3. Data tier: RDS, ElastiCache (cache and sessions groups), OpenSearch, Amazon MQ, EFS with mount targets.
4. ECR repositories; build and push images.
5. EKS cluster and managed node groups; install add-ons (CoreDNS, kube-proxy, VPC CNI, EBS CSI, EFS CSI).
6. IAM: OIDC provider or Pod Identity associations and service-account roles.
7. Controllers: AWS Load Balancer Controller, Container Insights, secrets integration, metrics-server (for HPA).
8. Route 53 hosted zone and ACM certificate (DNS validation).
9. Application: web Deployment, Service, Ingress, EFS PVC, CronJob, consumer Deployment, schema Job, HPA.
10. CloudWatch alarms and dashboards.

```bash
aws eks update-kubeconfig --region <region> --name <cluster-name>
kubectl get nodes
```

---

## 11. Operational Notes

- **Backups & DR:** see [Backup & Disaster Recovery](#12-backup--disaster-recovery).
- **Scaling:** Cluster Autoscaler or Karpenter for nodes; HPA for pods; RDS storage autoscaling.
- **Failover drills:** test RDS Multi-AZ failover, ElastiCache failover and AZ loss before go-live.
- **Cost:** multi-AZ NAT Gateways, dedicated OpenSearch masters and the RabbitMQ cluster are the main fixed costs; use smaller non-production sizing.

---

## 12. Backup & Disaster Recovery

### 12.1 Recovery Objectives

Targets only mean something if the mechanism behind them can actually meet them. The table lists the mechanism required for each target.

| Asset | Failure | RPO | RTO | Mechanism |
|---|---|---|---|---|
| Database | AZ / primary instance failure | 0 (synchronous standby) | Typically 60-120 s | RDS Multi-AZ automatic failover |
| Database | Logical corruption / bad deploy | <= 5 min | Restore time depends on DB size (plan for hours on large databases) | RDS point-in-time restore (PITR) |
| Database | Regional disaster | Typically minutes (not guaranteed) | See [12.3](#123-regional-disaster-recovery) | RDS cross-Region automated backup replication, or a cross-Region read replica |
| Catalog media (EFS) | Deletion / corruption | <= 1 hour | Depends on data size | AWS Backup, **hourly** schedule |
| Catalog media (EFS) | Regional disaster | Typically ~15 min | Minutes once the replica is promoted | EFS Replication to the secondary Region |
| Code & infrastructure | Any | 0 | Depends on pipeline | Git, Terraform, ECR images (replicated cross-Region) |
| Pods / nodes / AZ | AZ outage | n/a (stateless) | Automatic, minutes | Topology spread, HPA, node-group capacity in surviving AZs |

> **Correction to common assumptions:** a daily AWS Backup schedule gives an RPO of up to **24 hours**, not 1 hour. Likewise, copying only *weekly* snapshots to another Region gives a regional RPO of up to **7 days**. Neither meets the targets above, so this design uses hourly backups plus continuous replication.

### 12.2 Backup Architecture

#### A. Database (RDS MySQL)
- **Automated backups and PITR:** set the backup retention period to 30 days (the maximum is 35). The PITR window equals the retention period, and RDS uploads transaction logs about every 5 minutes, which is where the <= 5 minute RPO comes from.
- **Daily snapshots:** retained for 30 days in production (automated backups plus AWS Backup for centralised policy and reporting).
- **Cross-Region protection:** enable cross-Region automated backup replication (snapshots *and* transaction logs) to the secondary Region (for example `us-west-2`), or run a cross-Region read replica for the fastest recovery. Encrypted copies need a KMS key in the destination Region (use a multi-Region key or a dedicated key there).
- **Deletion protection** enabled, and a final snapshot required on delete.

#### B. Media assets (EFS)
- Media lives on **Amazon EFS** (not S3), so "S3 versioning" does not apply here unless you also store media in S3.
- **AWS Backup:** hourly backups (the minimum schedule interval is 1 hour), 30-day lifecycle, stored in a dedicated backup vault.
- **EFS Replication** to the secondary Region for regional DR.
- Local development fallback: `scripts/backup.sh` and `scripts/restore.sh` are for dev only and are not a production backup mechanism.

#### C. Infrastructure & Kubernetes state
- **Terraform state:** remote state in an encrypted, versioned S3 bucket. Use S3 native state locking (Terraform 1.10+, `use_lockfile`); DynamoDB-based locking is deprecated. Replicate the state bucket to the secondary Region, because state stored only in the failed Region is unavailable during the disaster.
- **Kubernetes:** Helm charts and manifests in Git (GitOps). The cluster itself is treated as disposable.
- **Container images:** ECR cross-Region replication, so the secondary Region can pull the same immutable tags.

#### D. Secrets & encryption keys
- Replicate Secrets Manager secrets to the secondary Region (multi-Region secrets).
- Back up the **Magento encryption key** (`crypt/key` in `app/etc/env.php`) in Secrets Manager. Without it, encrypted data in the database (stored tokens, encrypted config values) cannot be read after a restore.
- Keep `app/etc/config.php` in Git; keep environment-specific `env.php` values injected from Secrets Manager.

#### E. Search & cache (not backed up)
- **OpenSearch** is derived data. Rebuild it with `bin/magento indexer:reindex` after a restore, and size the RTO for how long a full reindex of your catalog takes. For very large catalogs, take OpenSearch snapshots to S3 to shorten recovery.
- **Redis** holds cache and sessions only. After a regional failover it starts empty: caches warm up and customers are logged out.
- **RabbitMQ** queues are transient; define exchanges/queues in configuration so they are recreated, and accept that in-flight messages may need replaying or reconciling.

#### F. Backup hardening
- Use AWS Backup **Vault Lock** (immutability) and consider a separate backup account to protect against ransomware and accidental or malicious deletion.
- Alert on failed or missed backup jobs (AWS Backup and RDS events to SNS/CloudWatch).
- Review restore permissions: restoring and deleting backups should require different IAM roles.

### 12.3 Regional Disaster Recovery

A target of **RTO <= 2 hours** is not realistic with a cold "redeploy with Terraform" approach alone. Creating an EKS cluster, an OpenSearch domain and a RabbitMQ broker takes tens of minutes each, restoring a large RDS database takes longer still, and a full reindex follows. To meet <= 2 hours, use a **pilot-light / warm-standby** design:

| Component | Secondary Region state |
|---|---|
| VPC, subnets, security groups | Always deployed (Terraform) |
| RDS | Cross-Region read replica (promote on disaster) or restore from replicated backups |
| EFS | Replica file system (EFS Replication) |
| EKS | Cluster and node group pre-created at minimal or zero scale; scale up on failover |
| ECR / Secrets Manager / KMS | Replicated (multi-Region keys and secrets) |
| ACM certificate | Issued in the secondary Region in advance |
| Route 53 | Health checks and failover (or manual) records ready |
| ElastiCache, OpenSearch, Amazon MQ | Provision at failover time (or keep small standby copies if the RTO requires it); OpenSearch is the usual long pole |

If the business accepts a longer RTO (for example 4-8 hours), a cold rebuild from Terraform and replicated backups is cheaper but must be rehearsed to confirm the real number.

### 12.4 Disaster Scenarios & Playbooks

#### Scenario 1: Availability Zone failure
- **Database:** RDS Multi-AZ detects the failure and promotes the synchronous standby, typically in **60-120 seconds** with no data loss. The endpoint DNS name stays the same, so the application must retry connections (set sensible DB connect timeouts and keep DNS TTL caching low).
- **Redis:** the replication group promotes a replica in a surviving AZ automatically.
- **OpenSearch and Amazon MQ:** zone awareness / cluster mode keep serving from remaining AZs.
- **Kubernetes:** pods rescheduled onto nodes in surviving AZs; the HPA adds replicas. Keep spare node capacity (or Karpenter / Cluster Autoscaler headroom) so the remaining AZs can absorb the load.

#### Scenario 2: Accidental database corruption or bad data change
Remember that a PITR restore creates a **new** instance, and rolling the live store back to time `T` **discards every legitimate order and customer change made after `T`**. Consider repairing only the affected tables from the restored copy instead of a full cutover.

1. **Contain:** stop further damage and writes. Suspend cron, scale down consumers and web (or enable maintenance mode):
   ```bash
   kubectl patch cronjob magento-cron -n magento -p '{"spec":{"suspend":true}}'
   kubectl scale deployment/magento-consumers deployment/magento-web -n magento --replicas=0
   ```
2. **Identify** the exact corruption timestamp `T` (application logs, CloudTrail, deployment history).
3. **Restore** to a new instance at `T - 1 minute` (RDS console: *Restore to point in time*, or `aws rds restore-db-instance-to-point-in-time`). Explicitly set the instance class, subnet group, **security groups, parameter group, option group, Multi-AZ and KMS key**, because these are not inherited automatically from the source instance.
4. **Validate** the restored data (row counts, recent orders and customers, application smoke test against the restored instance).
5. **Choose recovery path:**
   - *Targeted repair:* export the affected tables from the restored instance and import them into production, preserving later valid writes; or
   - *Full cutover:* rename the old instance (for example `-old`) and rename the restored one to the original identifier so the endpoint stays unchanged, or update the endpoint in the ConfigMap / Secrets Manager. Confirm credentials work on the restored instance (especially if you use RDS-managed master secrets).
6. **Resume:** bring the application back up:
   ```bash
   kubectl scale deployment/magento-web deployment/magento-consumers -n magento --replicas=<n>
   kubectl rollout restart deployment/magento-web -n magento
   kubectl patch cronjob magento-cron -n magento -p '{"spec":{"suspend":false}}'
   ```
7. **Post-restore consistency:** flush Redis cache/FPC, run `bin/magento cache:flush` and a full `indexer:reindex` so OpenSearch matches the restored database, and reconcile orders and payments for the gap window against your payment provider.
8. **Clean up:** import or reconcile the new instance in Terraform to avoid state drift, and delete the old instance only after sign-off.

#### Scenario 3: Accidental media deletion or EFS corruption
Restore the affected recovery point from AWS Backup into a **new** EFS file system (or restore specific items to an alternate directory), validate, then repoint the PersistentVolume or copy the files back. Purge CDN caches afterwards.

#### Scenario 4: Regional outage
1. Declare the disaster and freeze deployments.
2. Promote the RDS read replica (or restore from replicated backups) in the secondary Region.
3. Promote/use the EFS replica; mount it via the EFS CSI driver.
4. Scale up the pre-created EKS node group; deploy the application from Git/Helm using replicated ECR images and Secrets Manager secrets.
5. Provision or scale up ElastiCache, OpenSearch (restore snapshot or reindex) and Amazon MQ; update endpoints.
6. Switch Route 53 (and CDN origin) to the secondary ALB.
7. Validate checkout end to end, communicate status, and plan **fail-back** once the primary Region recovers.

### 12.5 Testing & Governance

- Run restore drills on a schedule (at least quarterly): a PITR restore, an EFS restore, an AZ-failure simulation and a full regional failover rehearsal. Record the actual RPO/RTO achieved and update the targets to match.
- Keep these playbooks version-controlled and review them after every drill or incident.
- Monitor backup freshness: alarm if the latest restorable time or last successful backup is older than the RPO.

---

## 13. Version & Support Checklist

Versions reach end of support on a schedule. Confirm each is currently supported and compatible with your Magento release before provisioning.

| Service | Version in this design | Check |
|---|---|---|
| Magento / Adobe Commerce | 2.4.7 | Confirm patch level and its published system requirements |
| Amazon EKS | Use a current version | Older Kubernetes versions move to paid extended support, then forced upgrade |
| RDS MySQL | 8.0 | Community support for 8.0 has ended; RDS Extended Support fees may apply. Move to 8.4 LTS only if your Magento version supports it |
| ElastiCache | Redis OSS 7.1 or Valkey 7.2 | "Redis 7.2" on ElastiCache is offered as Valkey 7.2; Redis OSS tops out at 7.1. Confirm Magento compatibility for your choice |
| OpenSearch | 2.x (for example 2.11 to 2.13) | Match the version listed in Magento's system requirements |
| Amazon MQ RabbitMQ | 3.13 | Confirm currently supported broker versions |

Always verify against current AWS documentation and Adobe's system requirements.
