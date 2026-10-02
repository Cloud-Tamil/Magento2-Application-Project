# Enterprise Production Security Standards

Security baseline for Magento 2 / Adobe Commerce on Amazon EKS and AWS managed services. These are the controls production must meet; the local development setup deliberately relaxes several of them.

---

## Table of Contents

1. [Secrets Management](#1-secrets-management)
2. [Identity & Access](#2-identity--access)
3. [Network Isolation](#3-network-isolation)
4. [Container Hardening](#4-container-hardening)
5. [Software Supply Chain](#5-software-supply-chain)
6. [Encryption Standards](#6-encryption-standards)
7. [Edge & Application Security](#7-edge--application-security)
8. [Detection, Audit & Response](#8-detection-audit--response)
9. [Verification Checklist](#9-verification-checklist)

---

## 1. Secrets Management

- **Zero plaintext secrets in Git.** Passwords and API tokens are generated randomly and stored in AWS Secrets Manager, encrypted with a customer-managed KMS key.
- **Terraform caveat:** values created with `random_password` also exist in Terraform state. Keep state in an encrypted, versioned, access-restricted S3 backend, and prefer `manage_master_user_password = true` for RDS so the master password never enters state.
- **Encryption keys:** KMS keys stay in KMS and are never exported. The Magento application key (`crypt/key`) is a secret and belongs in Secrets Manager (and in the DR backup set).
- **Rotation:** enable automatic rotation where supported (RDS managed secrets, supported database credentials). A rotation Lambda inside the VPC needs a Secrets Manager VPC endpoint because the DB subnets have no internet route.
- **Delivery to pods:** External Secrets Operator or the Secrets Store CSI Driver (AWS provider) using the pod's IAM role. Kubernetes Secrets are only base64-encoded, so enable EKS envelope encryption with KMS and restrict RBAC on them.
- **Never use phpMyAdmin for credential storage.** It is a database admin GUI. Storing credentials in database tables or in phpMyAdmin configuration is an anti-pattern, and phpMyAdmin must not be deployed to production at all.

---

## 2. Identity & Access

- **Kubernetes IRSA** (or EKS Pod Identity): pods assume IAM roles through OIDC web identity federation, so there are no static AWS access keys in pods. Scope each role to specific secret ARNs and bucket prefixes, and lock the trust policy to the exact namespace and ServiceAccount:

  ```json
  "Condition": {
    "StringEquals": {
      "oidc.eks.<region>.amazonaws.com/id/<OIDC_ID>:sub": "system:serviceaccount:magento:<serviceaccount>",
      "oidc.eks.<region>.amazonaws.com/id/<OIDC_ID>:aud": "sts.amazonaws.com"
    }
  }
  ```
- **Block pods from using the node role:** require IMDSv2 (`http_tokens = required`) and limit the metadata hop count on worker nodes (`http_put_response_hop_limit = 1` where add-ons use IRSA/Pod Identity), so a compromised pod cannot reach the node's credentials.
- **Humans:** single sign-on with MFA, no long-lived IAM users or shared accounts, a monitored break-glass role, least privilege, and separate roles for restoring and deleting backups.
- **Cluster access:** EKS access entries / RBAC with least privilege; restrict the EKS API endpoint to private access or a tight CIDR allow-list.

---

## 3. Network Isolation

### Subnet tiers
| Tier | Contains | Internet |
|---|---|---|
| Public | ALB and NAT Gateways only | Yes |
| Private App | EKS worker nodes and pods; no public IPs | Outbound via NAT only |
| Private DB | RDS MySQL, Redis, OpenSearch, Amazon MQ | **No ingress or egress route to the internet** |

### Security groups (defense in depth)
Data services accept traffic **only from the EKS node security group**:

| Service | Port | Source |
|---|---|---|
| RDS MySQL | 3306 | EKS node SG |
| ElastiCache Redis | 6379 | EKS node SG |
| OpenSearch | 443 | EKS node SG |
| Amazon MQ (RabbitMQ, AMQPS) | 5671 | EKS node SG |
| EFS (NFS) | 2049 | EKS node SG |

Further controls:
- **Kubernetes NetworkPolicies:** default-deny in the `magento` namespace, then allow only required flows (ALB to web, web to data tier, DNS). This needs a CNI with network policy enforcement (for example VPC CNI network policy support).
- **ALB security group:** allow 443/80 from the internet (or only from your CDN's IP ranges), and keep egress narrow on every security group.
- **Security groups for pods** can isolate individual workloads further when node-level rules are too broad.
- **VPC endpoints** (ECR, STS, Secrets Manager, CloudWatch Logs, S3) keep AWS API traffic off the NAT path.

---

## 4. Container Hardening

- **Non-root execution:** Nginx runs as UID 101 (use the unprivileged Nginx image, which listens on a port above 1024 such as 8080) and PHP-FPM as UID 33 (`www-data`). Set `runAsNonRoot: true` explicitly.
- **Restricted capabilities and escalation:** `capabilities.drop: ["ALL"]` and `allowPrivilegeEscalation: false`.
- **Root filesystem protection:** set `readOnlyRootFilesystem: true` and mount `emptyDir` volumes only for paths that must be writable (for example `var/`, `generated/`, `/tmp`, Nginx cache and run directories). Dropping capabilities alone does not make the filesystem read-only.
- **Seccomp:** `seccompProfile: RuntimeDefault`.
- **Pod Security Admission:** target the `restricted` profile (the settings above satisfy it); use `baseline` only while images are being fixed.
- **Service account tokens:** disable automounting of the default token for workloads that don't call the Kubernetes API.

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    fsGroup: 33
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: php-fpm
      securityContext:
        runAsUser: 33
        runAsGroup: 33
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
    - name: nginx
      securityContext:
        runAsUser: 101
        runAsGroup: 101
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
```

---

## 5. Software Supply Chain

- **Trivy scanning in CI/CD:** scan every image for CVEs **before** pushing to Amazon ECR, and fail the build on HIGH/CRITICAL findings (with a documented exceptions process). Also run `trivy config` on Terraform and Kubernetes manifests and scan for committed secrets.
- **ECR scanning:** keep scan-on-push enabled, and consider continuous (enhanced) scanning so newly published CVEs are caught in images already deployed.
- **Immutable tags:** ECR enforces `IMMUTABLE` tags to prevent tag-overwrite attacks. Tag by commit SHA (not `latest`) and deploy by tag or digest.
- **Provenance:** pin base images by digest, generate an SBOM, and sign images (for example Sigstore cosign or AWS Signer) with an admission policy (for example Kyverno) that only allows signed images from your ECR.
- **Dependencies:** audit Composer and OS packages; apply Adobe Commerce / Magento security patches promptly.

---

## 6. Encryption Standards

### In transit
| Path | Standard |
|---|---|
| Client to ALB | TLS 1.2+ (security policy set on the ALB, ACM certificate) |
| ALB to pods | Plain HTTP inside the VPC by default. Use an HTTPS target group and TLS on Nginx if your policy requires end-to-end encryption |
| Application to RDS | TLS required (`require_secure_transport = ON`), certificate verified |
| Application to Redis | In-transit encryption enabled, `tls://` connections |
| Application to OpenSearch | HTTPS (port 443), node-to-node encryption enabled |
| Application to RabbitMQ | AMQPS on port 5671 |

### At rest (AES-256 via AWS KMS)
RDS storage and snapshots, ElastiCache Redis, OpenSearch (EBS volumes), Amazon MQ, **EFS**, EBS volumes for nodes, ECR repositories, S3 buckets (Terraform state, logs, backups), Secrets Manager, Kubernetes Secrets (EKS envelope encryption), and CloudWatch Logs (optional KMS).

Notes:
- Several services can only enable encryption **at creation** (for example RDS and ElastiCache at-rest). Retrofitting means snapshot, copy-encrypted and restore, so set it from day one.
- Use customer-managed KMS keys with automatic rotation and least-privilege key policies. Use multi-Region keys where DR replication needs them.

---

## 7. Edge & Application Security

- **AWS WAF** on the ALB with managed rule groups, rate limiting and bot control; AWS Shield for DDoS. If a CDN fronts the ALB, lock the origin to the CDN (IP ranges or a secret header).
- **Admin hardening:** custom admin path, **2FA enabled in production** (the 2FA bypass is for local development only), IP allow-listing or VPN, strong password policy.
- **Magento configuration:** production mode, secure cookies (`Secure`, `HttpOnly`, `SameSite`), HTTPS everywhere, no directory listing, no phpMyAdmin or debug tooling, correct file permissions.
- **Payments:** use hosted fields or redirect-based payment methods to minimise PCI DSS scope. Never log card data.
- **Patching cadence:** Adobe security patches, PHP and extension updates, node AMI updates and EKS version upgrades on a regular schedule.

---

## 8. Detection, Audit & Response

- **Audit:** CloudTrail (all Regions, log file validation, protected bucket), EKS control-plane audit logs, VPC Flow Logs, AWS Config, ALB access logs.
- **Detection:** GuardDuty (including EKS audit-log and runtime protection), Security Hub, Amazon Inspector for container and host vulnerabilities.
- **Backups:** AWS Backup Vault Lock and a separate backup account to resist ransomware and malicious deletion (see the Backup & DR strategy).
- **Response:** documented incident runbooks (credential leak, compromised pod, DDoS, data exposure), secret rotation procedures, and regular tabletop exercises.

---

## 9. Verification Checklist

- [ ] No secrets in Git (CI secret scanning passing); Terraform state encrypted and access-restricted
- [ ] IRSA/Pod Identity roles scoped by namespace, ServiceAccount and resource ARN; IMDSv2 required on nodes
- [ ] DB subnets have no internet route; all five data-service security groups allow only `eks_nodes_sg`
- [ ] NetworkPolicies default-deny in the `magento` namespace
- [ ] Pods pass Pod Security `restricted`; read-only root filesystem with explicit writable volumes
- [ ] Trivy gate in CI; ECR scan on push; immutable tags; images signed and verified
- [ ] TLS 1.2+ on every hop listed above; encryption at rest on every store listed above
- [ ] WAF enabled; admin 2FA on; production mode on; phpMyAdmin absent
- [ ] CloudTrail, GuardDuty and Security Hub enabled; backup vault lock configured
