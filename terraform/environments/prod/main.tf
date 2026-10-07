# ==============================================================================
# Production Environment Infrastructure Definition
# Mission-Critical, Multi-AZ High Availability across 3 Availability Zones
# ==============================================================================

module "vpc" {
  source = "../../modules/vpc"

  environment              = var.environment
  cluster_name             = var.cluster_name
  vpc_cidr                 = "10.0.0.0/16"
  availability_zones       = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_app_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  private_db_subnet_cidrs  = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]
  single_nat_gateway       = false # Dedicated NAT Gateway per AZ for production fault-tolerance
}

module "security_groups" {
  source = "../../modules/security-groups"

  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  cluster_name = var.cluster_name
}

module "iam" {
  source = "../../modules/iam"

  environment = var.environment
  region      = var.aws_region
  account_id  = var.account_id
}

module "ecr" {
  source = "../../modules/ecr"

  environment          = var.environment
  image_tag_mutability = "IMMUTABLE" # Enforce strict immutability in production
}

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

  desired_size   = 5
  min_size       = 3
  max_size       = 20
  instance_types = ["c6i.2xlarge", "m6i.2xlarge"]
  capacity_type  = "ON_DEMAND"
  disk_size      = 100
}

module "secrets" {
  source = "../../modules/secrets"

  environment   = var.environment
  database_name = "magento2_prod"
  database_user = "magento_prod_admin"
  mq_user       = "magento_prod_mq"
  admin_user    = "prod_sysadmin"
}

module "rds" {
  source = "../../modules/rds"

  environment             = var.environment
  private_subnet_ids      = module.vpc.private_db_subnet_ids
  rds_security_group_id   = module.security_groups.rds_security_group_id
  database_name           = "magento2_prod"
  database_user           = "magento_prod_admin"
  database_password       = module.secrets.generated_db_password
  instance_class          = "db.m6g.xlarge"
  allocated_storage       = 100
  max_allocated_storage   = 1000
  iops                    = 6000
  storage_throughput      = 250
  multi_az                = true
  backup_retention_period = 30
  deletion_protection     = true
  skip_final_snapshot     = false
}

module "redis" {
  source = "../../modules/redis"

  environment                = var.environment
  private_subnet_ids         = module.vpc.private_db_subnet_ids
  redis_security_group_id    = module.security_groups.redis_security_group_id
  node_type                  = "cache.m6g.xlarge"
  num_cache_clusters         = 3
  automatic_failover_enabled = true
  multi_az_enabled           = true
  transit_encryption_enabled = true
  auth_token                 = module.secrets.generated_redis_auth_token
  snapshot_retention_limit   = 14
}

module "opensearch" {
  source = "../../modules/opensearch"

  environment                  = var.environment
  region                       = var.aws_region
  account_id                   = var.account_id
  private_subnet_ids           = module.vpc.private_db_subnet_ids
  opensearch_security_group_id = module.security_groups.opensearch_security_group_id
  engine_version               = "OpenSearch_2.11"
  instance_type                = "m6g.xlarge.search"
  instance_count               = 3
  volume_size                  = 100
  zone_awareness_enabled       = true
  availability_zone_count      = 3
  dedicated_master_enabled     = true
  dedicated_master_type        = "m6g.large.search"
  dedicated_master_count       = 3
}

module "mq" {
  source = "../../modules/mq"

  environment          = var.environment
  private_subnet_ids   = module.vpc.private_db_subnet_ids
  mq_security_group_id = module.security_groups.mq_security_group_id
  host_instance_type   = "mq.m5.xlarge"
  deployment_mode      = "CLUSTER_MULTI_AZ"
  mq_admin_username    = "magento_prod_mq"
  mq_admin_password    = module.secrets.generated_mq_password
}

module "alb" {
  source = "../../modules/alb"

  environment       = var.environment
  account_id        = var.account_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}

module "route53" {
  source = "../../modules/route53"

  environment = var.environment
  domain_name = var.domain_name
  zone_id     = var.route53_zone_id
}

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  environment        = var.environment
  cluster_name       = var.cluster_name
  log_retention_days = 90
}
