# Magento 2 Enterprise DevOps Architecture Specification

## 1. System Overview

This enterprise architecture is designed for Adobe Commerce / Magento 2.4.7 running on Kubernetes (Amazon EKS) with AWS managed primitives. It provides automated autoscaling, zero-downtime rolling deployments, isolated private networking, multi-AZ resilience, and centralized observability.

```
                              [ Users / CDN / Cloudflare ]
                                          |
                                     (HTTPS 443)
                                          v
                    [ AWS Application Load Balancer (ALB) ]
                                          |
                        (NodePort / Ingress TargetGroup)
                                          v
      +-----------------------------------------------------------------------+
      | AWS EKS Cluster (Private Worker Node Subnets - 3 AZs)                 |
      |                                                                       |
      |   [ Ingress (AWS Load Balancer Controller) ]                          |
      |                    |                                                  |
      |                    v                                                  |
      |           [ magento-service (NodePort) ]                              |
      |                    |                                                  |
      |   +----------------+----------------+                                 |
      |   |                                 |                                 |
      |   v                                 v                                 |
      | [ Magento Pod 1 ]           [ Magento Pod 2 ]           ... [ Pod N ] |
      |   ├── Nginx Container         ├── Nginx Container                     |
      |   └── PHP-FPM Container       └── PHP-FPM Container                   |
      |   ├── Mount: EFS Media        ├── Mount: EFS Media                    |
      |   └── ServiceAccount (IRSA)   └── ServiceAccount (IRSA)               |
      |                                                                       |
      |   [ CronJob Pods: magento cron:run every 1 min ]                      |
      |   [ HPA: Horizontal Pod Autoscaler (CPU 70% / Mem 80%) ]              |
      +-----------------------------------------------------------------------+
                     |                 |               |               |
                     v                 v               v               v
            +-----------------+ +-------------+ +-------------+ +-------------+
            |  AWS RDS MySQL  | | ElastiCache | |  OpenSearch | |  Amazon MQ  |
            |     Multi-AZ    | |    Redis    | |   Cluster   | |  RabbitMQ   |
            |   (Port 3306)   | | (Port 6379) | | (Port 443)  | | (Port 5671) |
            +-----------------+ +-------------+ +-------------+ +-------------+
                     ^                 ^               ^               ^
                     |                 |               |               |
                     +-----------------+---------------+---------------+
                                       |
                     [ AWS Secrets Manager (Credentials) ]
                     [ EKS Pod Identity / IAM IRSA ]
```

## 2. Secrets Management & Storage Rules

### Architectural Mandate
- **phpMyAdmin IS NEVER A SECRETS VAULT**: phpMyAdmin is strictly an interactive SQL administration tool for developers during local debugging. Storing application passwords, AWS credentials, or API tokens in phpMyAdmin tables is strictly prohibited.
- **Local Development**: `.env` (derived from `.env.example`, gitignored).
- **Kubernetes**: Kubernetes Secrets mounted as environment variables (`envFrom`) or files.
- **Production AWS**: AWS Secrets Manager, with encryption via AWS KMS. Pods retrieve credentials directly through IRSA or through the Kubernetes External Secrets Operator.
- **Terraform**: Zero plaintext passwords committed to Git. Passwords are generated using `random_password` and stored immediately in AWS Secrets Manager.

## 3. High Availability & Data Persistence

1. **Shared Media Storage**:
   - Magento product images, catalog media, and dynamic uploads in `pub/media/` are stored on AWS EFS (Elastic File System) using the AWS EFS CSI driver (`ReadWriteMany`).
   - Static generated assets (`pub/static/`) are compiled into immutable Docker images during the CI/CD pipeline, avoiding runtime NFS latency.
2. **Relational Database**:
   - AWS RDS MySQL 8.0 configured with Multi-AZ synchronous standby replication.
   - Deployed strictly in private database subnets with automated backups, performance insights, and storage autoscaling.
3. **Session & Cache Tier**:
   - Redis 7.2 Multi-AZ Replication Group.
   - Database 0: Default Cache
   - Database 1: Full Page Cache (FPC)
   - Database 2: PHP Sessions (persisted with Redis LRU eviction safeguards)
4. **Catalog Search Engine**:
   - AWS OpenSearch 2.11/2.13 Multi-AZ domain with 3 dedicated master nodes and 3 data nodes.
5. **Message Queuing**:
   - Amazon MQ for RabbitMQ in a high-availability active/standby or cluster broker deployment.
