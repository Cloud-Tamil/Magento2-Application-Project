output "database_secret_arn" {
  description = "ARN of the Database Secrets Manager secret"
  value       = aws_secretsmanager_secret.database.arn
}

output "redis_secret_arn" {
  description = "ARN of the Redis Secrets Manager secret"
  value       = aws_secretsmanager_secret.redis.arn
}

output "rabbitmq_secret_arn" {
  description = "ARN of the RabbitMQ Secrets Manager secret"
  value       = aws_secretsmanager_secret.rabbitmq.arn
}

output "app_secret_arn" {
  description = "ARN of the App Admin Secrets Manager secret"
  value       = aws_secretsmanager_secret.app.arn
}

output "generated_db_password" {
  description = "Generated MySQL Master password"
  value       = random_password.mysql.result
  sensitive   = true
}

output "generated_redis_auth_token" {
  description = "Generated Redis Auth Token"
  value       = random_password.redis.result
  sensitive   = true
}

output "generated_mq_password" {
  description = "Generated RabbitMQ password"
  value       = random_password.rabbitmq.result
  sensitive   = true
}
