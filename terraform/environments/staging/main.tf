# ==============================================================================
# Staging Environment Infrastructure Definition
# Mirroring production architecture for true pre-flight staging verification
# ==============================================================================

module "vpc" {
  source = "../../modules/vpc"

  environment              = var.environment
  cluster_name             = var.cluster_name
  vpc_cidr                 = "10.20.0.0/16"
  availability_zones       = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnet_cidrs      = ["10.20.1.0/24", "10.20.2.0/24"]
  private_app_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]
  private_db_subnet_cidrs  = ["10.20.20.0/24", "10.20.21.0/24"]
  single_nat_gateway       = false
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
  image_tag_mutability = "MUTABLE"
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

  desired_size   = 3
  min_size       = 2
  max_size       = 6
  instance_types = ["c6i.xlarge", "m6i.xlarge"]
  capacity_type  = "ON_DEMAND"
  disk_size      = 60
}

module "secrets" {
  source = "../../modules/secrets"

  environment   = var.environment
  database_name = "magento2_staging"
  database_user = "magento_staging_user"
  mq_user       = "magento_staging_mq"
  admin_user    = "staging_admin"
}

module "rds" {
  source = "../../modules/rds"

  environment             = var.environment
  private_subnet_ids      = module.vpc.private_db_subnet_ids
  rds_security_group_id   = module.security_groups.rds_security_group_id
  database_name           = "magento2_staging"
  database_user           = "magento_staging_user"
  database_password       = module.secrets.generated_db_password
  instance_class          = "db.m6g.large"
  allocated_storage       = 50
  max_allocated_storage   = 200
  multi_az                = true
  backup_retention_period = 7
  deletion_protection     = true
  skip_final_snapshot     = false
}

module "redis" {
  source = "../../modules/redis"

  environment                = var.environment
  private_subnet_ids         = module.vpc.private_db_subnet_ids
  redis_security_group_id    = module.security_groups.redis_security_group_id
  node_type                  = "cache.m6g.large"
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true
  transit_encryption_enabled = false
}

module "opensearch" {
  source = "../../modules/opensearch"

  environment                  = var.environment
  region                       = var.aws_region
  account_id                   = var.account_id
  private_subnet_ids           = module.vpc.private_db_subnet_ids
  opensearch_security_group_id = module.security_groups.opensearch_security_group_id
  engine_version               = "OpenSearch_2.11"
  instance_type                = "m6g.large.search"
  instance_count               = 2
  volume_size                  = 30
  zone_awareness_enabled       = true
}

module "mq" {
  source = "../../modules/mq"

  environment          = var.environment
  private_subnet_ids   = module.vpc.private_db_subnet_ids
  mq_security_group_id = module.security_groups.mq_security_group_id
  host_instance_type   = "mq.m5.large"
  deployment_mode      = "CLUSTER_MULTI_AZ"
  mq_admin_username    = "magento_staging_mq"
  mq_admin_password    = module.secrets.generated_mq_password
}

module "alb" {
  source = "../../modules/alb"

  environment       = var.environment
  account_id        = var.account_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  environment        = var.environment
  cluster_name       = var.cluster_name
  log_retention_days = 14
}
