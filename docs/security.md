# Enterprise Production Security Standards

## 1. Secrets Management
- **Zero Plaintext Secrets**: Passwords, API tokens, and encryption keys are generated randomly and stored directly in AWS Secrets Manager.
- **Never Use phpMyAdmin for Credential Storage**: phpMyAdmin is strictly a DB admin GUI. Storing credentials inside DB tables or phpMyAdmin configuration is an anti-pattern.
- **Kubernetes IRSA**: Pods assume IAM roles dynamically via OpenID Connect (OIDC) web identity federation, eliminating static AWS Access Keys in Pods.

## 2. Network Isolation
- **Subnet Micro-Segmentation**:
  - Public Subnets: ALB and NAT Gateways only.
  - Private App Subnets: EKS worker nodes and Pods. No public IPs.
  - Private DB Subnets: RDS MySQL, Redis, OpenSearch, Amazon MQ. Absolutely no internet ingress or egress route.
- **Security Groups Defense-in-Depth**:
  - RDS accepts port 3306 exclusively from EKS node security groups.
  - Redis accepts port 6379 exclusively from EKS node security groups.
  - OpenSearch accepts port 443 exclusively from EKS node security groups.

## 3. Container Hardening
- **Non-Root Execution**: Both Nginx (UID 101) and PHP-FPM (UID 33 / `www-data`) run as unprivileged users.
- **Root Filesystem Protection**: Capabilities dropped (`drop: ["ALL"]`), `allowPrivilegeEscalation: false`.
- **Trivy Image Scanning**: Every image built in CI/CD is scanned for CVEs before pushing to Amazon ECR.
- **Immutable Tags in Production**: ECR enforces `IMMUTABLE` image tags to prevent tag overwriting attacks.

## 4. Encryption Standards
- **In-Transit**: TLS 1.2+ enforced at Application Load Balancer and internal OpenSearch / Redis / RabbitMQ connections.
- **At-Rest**: AES-256 / AWS KMS encryption on RDS storage, ElastiCache Redis, OpenSearch EBS volumes, ECR repositories, and S3 state buckets.
