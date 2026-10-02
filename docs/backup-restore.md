# Backup & Disaster Recovery Strategy

## 1. Recovery Objectives (Targets)

- **Recovery Point Objective (RPO)**:
  - Database: <= 5 minutes (RDS Point-In-Time Restore continuous transaction logs)
  - Catalog Media: <= 1 hour (AWS Backup EFS / S3 versioning)
  - Code & Infrastructure: 0 minutes (Git & Terraform versioned state)
- **Recovery Time Objective (RTO)**:
  - Pod / Availability Zone Outage: Automatic failover within 60–120 seconds
  - Regional Disaster Recovery: <= 2 hours (Terraform redeployment to secondary region)

## 2. Backup Architecture

### A. Database (RDS MySQL)
- **Automated Daily Snapshots**: Retained for 30 days in production.
- **Continuous Transaction Logs (Point-In-Time Recovery)**: Allows restoring database to any specific second within the retention window.
- **Cross-Region Snapshot Copy**: Weekly snapshots copied to secondary AWS region (`us-west-2`) for regional disaster recovery.

### B. Media Assets (EFS / S3)
- AWS Backup scheduled daily at 02:00 UTC with 30-day lifecycle rule.
- Local development fallback: `scripts/backup.sh` and `scripts/restore.sh`.

### C. Infrastructure & Kubernetes State
- Terraform remote state versioned in encrypted S3 with DynamoDB locking.
- Helm chart and Kubernetes manifests stored in Git.

## 3. Disaster Scenarios & Playbooks

### Scenario 1: Availability Zone (AZ) Failure
- **Behavior**: AWS Multi-AZ RDS automatically detects primary AZ failure and promotes the synchronous standby replica in under 60 seconds without data loss.
- **Kubernetes**: EKS worker nodes in surviving AZs absorb traffic; HPA spins up additional replicas to meet minimum requirements.

### Scenario 2: Accidental Database Data Corruption
- **Playbook**:
  1. Identify exact corruption timestamp `T`.
  2. In RDS Console, choose **Restore to Point In Time** for `T - 1 minute`.
  3. Validate restored instance data integrity.
  4. Update Kubernetes ConfigMap / AWS Secrets Manager to point to the restored RDS instance endpoint.
  5. Restart Magento pods: `kubectl rollout restart deployment/magento-web -n magento`.
