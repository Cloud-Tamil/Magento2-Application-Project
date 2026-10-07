# Terraform Modular Infrastructure Guide

## Directory Layout

```
terraform/
├── environments/
│   ├── dev/                 # Single-AZ/NAT, spot instances, cost optimized
│   ├── staging/             # Multi-AZ mirror of production
│   └── prod/                # Enterprise 3-AZ, dedicated masters, encrypted, immutable tags
└── modules/
    ├── vpc/                 # Multi-AZ networking & subnet tiering
    ├── security-groups/     # Micro-segmented firewalls
    ├── iam/                 # Control plane, node group & IRSA roles
    ├── ecr/                 # Container image repositories
    ├── eks/                 # EKS cluster & managed node groups
    ├── rds/                 # Private MySQL 8.0 RDS
    ├── redis/               # ElastiCache Redis replication group
    ├── opensearch/          # OpenSearch search cluster
    ├── mq/                  # Amazon MQ RabbitMQ broker
    ├── alb/                 # AWS Load Balancer Controller IAM
    ├── route53/             # ACM certificate & Route53 records
    ├── secrets/             # AWS Secrets Manager password generator
    ├── cloudwatch/          # Log groups & alarms
    └── s3-state/            # Remote state bucket & DynamoDB lock table
```

## Standard Execution Workflow

### 1. Set up Remote State Backend (One-time)
```bash
# Provision remote state S3 bucket and DynamoDB locking table
cd terraform/modules/s3-state
terraform init
terraform apply -var="account_id=123456789012"
```

### 2. Deploy an Environment (e.g., Development)
```bash
cd terraform/environments/dev

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Format and Validate
terraform fmt -check
terraform validate

# Initialize providers and remote backend
terraform init

# Generate Execution Plan
terraform plan -out=tfplan

# Apply Infrastructure Changes
terraform apply tfplan

# Inspect Outputs
terraform output
```

### 3. Teardown
```bash
terraform destroy
```
