# ==============================================================================
# RDS Module - Private, Multi-AZ MySQL 8.0 for Magento 2
# ==============================================================================

# Private DB Subnet Group
resource "aws_db_subnet_group" "rds" {
  name        = "${var.environment}-rds-subnet-group"
  subnet_ids  = var.private_subnet_ids
  description = "Private subnets for Magento RDS MySQL"

  tags = merge(var.tags, { Name = "${var.environment}-rds-subnet-group" })
}

# Magento-Optimized MySQL 8.0 Parameter Group
resource "aws_db_parameter_group" "rds" {
  name        = "${var.environment}-magento-mysql80-params"
  family      = "mysql8.0"
  description = "Magento 2 optimized parameter group for MySQL 8.0"

  parameter {
    name  = "max_allowed_packet"
    value = "134217728" # 128MB
  }

  parameter {
    name  = "binlog_format"
    value = "ROW"
  }

  parameter {
    name  = "log_bin_trust_function_creators"
    value = "1"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  tags = var.tags
}

# Production RDS MySQL Instance
resource "aws_db_instance" "rds" {
  identifier                  = "${var.environment}-magento-rds"
  engine                      = "mysql"
  engine_version              = "8.0.36"
  instance_class              = var.instance_class
  allocated_storage           = var.allocated_storage
  max_allocated_storage       = var.max_allocated_storage
  storage_type                = "gp3"
  iops                        = var.iops
  storage_throughput          = var.storage_throughput
  db_name                     = var.database_name
  username                    = var.database_user
  password                    = var.database_password
  port                        = 3306
  multi_az                    = var.multi_az
  publicly_accessible         = false # Strictly private!
  vpc_security_group_ids      = [var.rds_security_group_id]
  db_subnet_group_name        = aws_db_subnet_group.rds.name
  parameter_group_name        = aws_db_parameter_group.rds.name
  storage_encrypted           = true
  kms_key_id                  = var.kms_key_arn
  backup_retention_period     = var.backup_retention_period
  backup_window               = "03:00-04:00"
  maintenance_window          = "Sun:04:30-Sun:05:30"
  auto_minor_version_upgrade  = false
  deletion_protection         = var.deletion_protection
  skip_final_snapshot         = var.skip_final_snapshot
  final_snapshot_identifier   = "${var.environment}-magento-rds-final-snap"
  copy_tags_to_snapshot       = true

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = merge(var.tags, { Name = "${var.environment}-magento-rds" })
}
