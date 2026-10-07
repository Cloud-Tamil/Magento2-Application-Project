# ==============================================================================
# ElastiCache Redis Module - Multi-AZ Clustered In-Memory Cache for Magento 2
# ==============================================================================

resource "aws_elasticache_subnet_group" "redis" {
  name        = "${var.environment}-redis-subnet-group"
  subnet_ids  = var.private_subnet_ids
  description = "Private Subnet Group for Magento ElastiCache Redis"

  tags = merge(var.tags, { Name = "${var.environment}-redis-subnet-group" })
}

resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.environment}-magento-redis7-params"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru"
  }

  tags = var.tags
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.environment}-magento-redis"
  description                = "Magento 2 Cache and Session Storage Replication Group"
  node_type                  = var.node_type
  num_cache_clusters         = var.num_cache_clusters
  port                       = 6379
  parameter_group_name       = aws_elasticache_parameter_group.redis.name
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [var.redis_security_group_id]
  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled
  engine_version             = "7.1"
  at_rest_encryption_enabled = true
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = var.transit_encryption_enabled ? var.auth_token : null

  auto_minor_version_upgrade = true
  maintenance_window         = "sun:05:00-sun:06:00"
  snapshot_window            = "02:00-03:00"
  snapshot_retention_limit   = var.snapshot_retention_limit

  tags = merge(var.tags, { Name = "${var.environment}-magento-redis" })
}
