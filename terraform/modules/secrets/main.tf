# ==============================================================================
# AWS Secrets Manager Module - Production Credential Vault
# 
# ARCHITECTURE PRINCIPLE:
# Passwords are NOT hardcoded in Terraform or Git.
# Secrets Manager generates or securely holds encrypted credentials,
# and EKS Pods consume them via IAM IRSA or External Secrets Operator.
# ==============================================================================

# Random Secure Passwords for initial automated provisioning
resource "random_password" "mysql" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "redis" {
  length           = 32
  special          = false # Redis auth token is alphanumeric
}

resource "random_password" "rabbitmq" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "magento_admin" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_id" "crypt_key" {
  byte_length = 16
}

# 1. Database Secrets
resource "aws_secretsmanager_secret" "database" {
  name                    = "${var.environment}/magento/database"
  description             = "Production MySQL Database Credentials for Magento"
  recovery_window_in_days = 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    username = var.database_user
    password = random_password.mysql.result
    database = var.database_name
  })
}

# 2. Redis Secrets
resource "aws_secretsmanager_secret" "redis" {
  name                    = "${var.environment}/magento/redis"
  description             = "Production ElastiCache Redis Credentials"
  recovery_window_in_days = 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    auth_token = random_password.redis.result
  })
}

# 3. RabbitMQ Secrets
resource "aws_secretsmanager_secret" "rabbitmq" {
  name                    = "${var.environment}/magento/rabbitmq"
  description             = "Production Amazon MQ RabbitMQ Credentials"
  recovery_window_in_days = 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "rabbitmq" {
  secret_id = aws_secretsmanager_secret.rabbitmq.id
  secret_string = jsonencode({
    username = var.mq_user
    password = random_password.rabbitmq.result
  })
}

# 4. Magento Admin & Encryption Secrets
resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.environment}/magento/app"
  description             = "Production Magento Admin and Crypt Key"
  recovery_window_in_days = 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    admin_user     = var.admin_user
    admin_password = random_password.magento_admin.result
    crypt_key      = random_id.crypt_key.hex
  })
}
