# ==============================================================================
# Development Environment Infrastructure Definition
# Cost-optimized, single NAT Gateway, developer sizing
# ==============================================================================

# 1. VPC Module
module "vpc" {
  source = "../../modules/vpc"

  environment              = var.environment
  cluster_name             = var.cluster_name
  vpc_cidr                 = "10.10.0.0/16"
  availability_zones       = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnet_cidrs      = ["10.10.1.0/24", "10.10.2.0/24"]
  private_app_subnet_cidrs = ["10.10.10.0/24", "10.10.11.0/24"]
  private_db_subnet_cidrs  = ["10.10.20.0/24", "10.10.21.0/24"]
  single_nat_gateway       = true # Cost saver for dev
}

# 2. Security Groups Module
module "security_groups" {
  source = "../../modules/security-groups"

  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  cluster_name = var.cluster_name
}

# 3. IAM Module (Base EKS control plane and nodes)
module "iam" {
  source = "../../modules/iam"

  environment = var.environment
  region      = var.aws_region
  account_id  = var.account_id
}

# 4. ECR Module
module "ecr" {
  source = "../../modules/ecr"

  environment          = var.environment
  image_tag_mutability = "MUTABLE"
}

# 5. EKS Cluster Module
module "eks" {
  source = "../../modules/eks"

  environment            = var.environment
  cluster_name           = var.cluster_name
  kubernetes_version     = "1.30"
  cluster_role_arn       = module.iam.eks_cluster_role_arn
  node_role_arn          = module.iam.eks_nodes_role_arn
  private_subnet_ids     = module.vpc.private_app_subnet_ids
  public_subnet_ids      = module.vpc.public_subnet_ids
  node_security_group_id = module.security_groups.eks_nodes_security_group_id

  # Dev sizing
  desired_size   = 2
  min_size       = 1
  max_size       = 4
  instance_types = ["t4g.xlarge", "c6g.xlarge"]
  capacity_type  = "SPOT" # Save up to 70% in dev
  disk_size      = 50
}

# 6. AWS Secrets Manager Module
module "secrets" {
  source = "../../modules/secrets"

  environment   = var.environment
  database_name = "magento2_dev"
  database_user = "magento_dev_user"
  mq_user       = "magento_dev_mq"
  admin_user    = "dev_admin"
}

# 7. RDS MySQL Module
module "rds" {
  source = "../../modules/rds"

  environment             = var.environment
  private_subnet_ids      = module.vpc.private_db_subnet_ids
  rds_security_group_id   = module.security_groups.rds_security_group_id
  database_name           = "magento2_dev"
  database_user           = "magento_dev_user"
  database_password       = module.secrets.generated_db_password
  instance_class          = "db.t4g.medium"
  allocated_storage       = 30
  max_allocated_storage   = 100
  multi_az                = false # Save cost in dev
  backup_retention_period = 3
  deletion_protection     = false
  skip_final_snapshot     = true
}

# 8. ElastiCache Redis Module
module "redis" {
  source = "../../modules/redis"

  environment                = var.environment
  private_subnet_ids         = module.vpc.private_db_subnet_ids
  redis_security_group_id    = module.security_groups.redis_security_group_id
  node_type                  = "cache.t4g.medium"
  num_cache_clusters         = 1 # Single node for dev
  automatic_failover_enabled = false
  multi_az_enabled           = false
  transit_encryption_enabled = false
}

# 9. OpenSearch Module
module "opensearch" {
  source = "../../modules/opensearch"

  environment                  = var.environment
  region                       = var.aws_region
  account_id                   = var.account_id
  private_subnet_ids           = [module.vpc.private_db_subnet_ids[0]]
  opensearch_security_group_id = module.security_groups.opensearch_security_group_id
  engine_version               = "OpenSearch_2.11"
  instance_type                = "t3.small.search"
  instance_count               = 1
  volume_size                  = 20
  zone_awareness_enabled       = false
}

# 10. Amazon MQ Module
module "mq" {
  source = "../../modules/mq"

  environment          = var.environment
  private_subnet_ids   = module.vpc.private_db_subnet_ids
  mq_security_group_id = module.security_groups.mq_security_group_id
  host_instance_type   = "mq.t3.micro"
  deployment_mode      = "SINGLE_INSTANCE"
  mq_admin_username    = "magento_dev_mq"
  mq_admin_password    = module.secrets.generated_mq_password
}

# 11. ALB Controller IAM Module
module "alb" {
  source = "../../modules/alb"

  environment       = var.environment
  account_id        = var.account_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}

# 12. CloudWatch Module
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  environment        = var.environment
  cluster_name       = var.cluster_name
  log_retention_days = 7
}
