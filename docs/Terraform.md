# Terraform Modular Infrastructure Guide

Infrastructure as code for the Magento 2 / Adobe Commerce platform on AWS: networking, EKS, data services, secrets, DNS/TLS and observability, composed from reusable modules into `dev`, `staging` and `prod` environments.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Directory Layout](#2-directory-layout)
3. [Environments](#3-environments)
4. [Standard Execution Workflow](#4-standard-execution-workflow)
5. [Teardown](#5-teardown)
6. [Conventions & CI/CD](#6-conventions--cicd)

---

## 1. Prerequisites

- Terraform with a pinned version (see `required_version` in each environment). S3 native state locking needs a recent release (Terraform 1.11+; it appeared experimentally in 1.10).
- AWS CLI authenticated with an appropriately scoped role (for example `aws sso login --profile <profile>`); confirm with `aws sts get-caller-identity`.
- `kubectl` and Helm for post-apply cluster setup.
- Commit `.terraform.lock.hcl` so provider versions are reproducible.

---

## 2. Directory Layout

```
terraform/
├── bootstrap/               # Root config that creates the remote state backend (one-time)
├── environments/
│   ├── dev/                 # Single NAT Gateway, spot nodes, cost optimized
│   ├── staging/             # Multi-AZ mirror of production
│   └── prod/                # Enterprise 3-AZ, dedicated masters, encrypted, immutable tags
└── modules/
    ├── vpc/                 # Multi-AZ networking & subnet tiering
    ├── security-groups/     # Micro-segmented firewalls
    ├── iam/                 # Control plane, node group & IRSA roles
    ├── ecr/                 # Container image repositories
    ├── eks/                 # EKS cluster & managed node groups
    ├── rds/                 # Private MySQL RDS
    ├── redis/               # ElastiCache Redis replication groups
    ├── opensearch/          # OpenSearch search cluster
    ├── mq/                  # Amazon MQ RabbitMQ broker
    ├── alb/                 # IAM for the AWS Load Balancer Controller
    ├── route53/             # ACM certificate & Route 53 records
    ├── secrets/             # AWS Secrets Manager password generation
    ├── cloudwatch/          # Log groups & alarms
    └── s3-state/            # Remote state bucket (and optional legacy lock table)
```

Notes on the layout:

- **`bootstrap/`** is a small root configuration that calls `modules/s3-state`. A module is meant to be called, not applied directly, so running `terraform apply` inside `modules/s3-state` only works if that folder carries its own provider block.
- **`alb/`** only creates the IAM role and policy for the AWS Load Balancer Controller. The ALB itself is created by the controller from the Kubernetes `Ingress`, not by Terraform. Installing the controller (Helm) is a separate step.
- **Modules missing from the list** that the architecture depends on: **`efs`** (shared `pub/media` storage with mount targets and security group), **`kms`** (customer-managed keys for every encrypted service), and ideally **`backup`** (AWS Backup plans and vault) and **`waf`**. Add them, or confirm they live inside another module.
- **Subnets in two or more AZs are required even in `dev`.** RDS subnet groups and the ALB need at least two AZs, so "single-AZ" in dev means one NAT Gateway and single-instance data services, not a single subnet.

---

## 3. Environments

| Aspect | dev | staging | prod |
|---|---|---|---|
| Purpose | Cost-optimized development | Multi-AZ mirror of production | Enterprise production |
| Availability Zones | 2 (subnets), single NAT Gateway | 3 | 3, one NAT Gateway per AZ |
| EKS nodes | Spot instances acceptable | On-demand | On-demand, sized for HPA max |
| Data services | Single-instance, smaller classes | Multi-AZ, production topology | Multi-AZ, dedicated OpenSearch masters, RabbitMQ cluster |
| Encryption | KMS on | KMS on | KMS on, immutable ECR tags |
| Deletion protection | Off (teardown allowed) | On | On, plus `prevent_destroy` on critical resources |

Keep staging structurally identical to prod and differ only by size, so staging tests are representative. Use separate state files per environment and, ideally, separate AWS accounts.

---

## 4. Standard Execution Workflow

### 1. Set up the remote state backend (one-time)

```bash
cd terraform/bootstrap
terraform init
terraform apply -var="account_id=123456789012"
```

- The bootstrap configuration itself uses **local state** (it creates the bucket it would otherwise store state in). Keep that state safe, or migrate it into the new bucket afterwards with `terraform init -migrate-state`.
- The state bucket should have: versioning, KMS encryption, public access fully blocked, a policy denying non-TLS access, `prevent_destroy`, and cross-Region replication so state survives a regional outage (see the DR strategy).
- **State locking:** use S3 native locking (`use_lockfile = true`). DynamoDB-based locking is deprecated, so the lock table is only needed on older Terraform versions.

Backend configuration for each environment (backend blocks cannot use variables, so use literal values or `-backend-config`):

```hcl
terraform {
  required_version = ">= 1.11"

  backend "s3" {
    bucket       = "<state-bucket>"
    key          = "magento/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    kms_key_id   = "<kms-key-arn>"
    use_lockfile = true
  }
}
```

### 2. Deploy an environment (for example development)

```bash
cd terraform/environments/dev

# Copy example variables (no secrets in tfvars; keep the real file out of Git)
cp terraform.tfvars.example terraform.tfvars

# Initialize providers and the remote backend (must come before validate)
terraform init

# Format and validate
terraform fmt -check -recursive
terraform validate

# Generate an execution plan
terraform plan -out=tfplan

# Apply exactly what was planned
terraform apply tfplan

# Inspect outputs
terraform output

# Plan files can contain sensitive values; do not commit or share them
rm tfplan
```

Expect a long first apply: EKS, OpenSearch and Amazon MQ each take on the order of 15-30 minutes to create.

### 3. After apply

```bash
aws eks update-kubeconfig --region <region> --name <cluster-name>
kubectl get nodes
```

Then install the cluster controllers (AWS Load Balancer Controller, metrics-server, EBS/EFS CSI, secrets integration) and deploy the application manifests as described in the Kubernetes guide.

---

## 5. Teardown

`terraform destroy` is for **dev only**. Production should never be destroyed with a single command: keep deletion protection, `prevent_destroy` and final snapshots on, and require approvals.

Before destroying a development environment:

```bash
# 1. Delete workloads that created AWS resources outside Terraform
#    (the Ingress creates an ALB, security groups and ENIs that block VPC deletion)
kubectl delete ingress --all -n magento
# wait until the ALB is gone, then:

# 2. Preview what will be removed
cd terraform/environments/dev
terraform plan -destroy

# 3. Destroy
terraform destroy
```

Gotchas that make destroy fail or leave leftovers:

- **ECR repositories with images** and **non-empty S3 buckets** need force-delete settings in dev.
- **Secrets Manager** secrets enter a recovery window after deletion (7-30 days), so re-creating the same name fails until it expires. In dev, set the recovery window to 0.
- **RDS** with deletion protection or a required final snapshot will refuse to delete until you change those settings.
- **The state bucket** is destroyed last and separately (remove `prevent_destroy` first), never as part of an environment teardown.

---

## 6. Conventions & CI/CD

- **Modules:** versioned, with documented inputs and outputs, `validation` blocks on variables, and consistent tagging (`Environment`, `Project`, `Owner`, `CostCenter`).
- **Environments as directories**, not Terraform workspaces, so each has its own backend key, variables and review path.
- **Pipeline:** run `fmt`, `validate`, `tflint` and a security scan (Trivy `config` or Checkov) on pull requests; post the `terraform plan` for review; apply on merge with manual approval for staging and prod.
- **CI authentication:** use GitHub Actions or GitLab OIDC to assume an AWS role, with no static AWS keys stored in CI.
- **Secrets:** generated values live in Secrets Manager. `random_password` results are also stored in state, so keep the state backend encrypted and access-restricted, and prefer RDS-managed master passwords.
- **Drift and cost:** schedule `terraform plan` to detect drift, and consider cost estimation (for example Infracost) on pull requests.
