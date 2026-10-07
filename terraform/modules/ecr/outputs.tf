output "app_repository_url" {
  description = "ECR URL for Magento PHP-FPM app image"
  value       = aws_ecr_repository.magento_app.repository_url
}

output "nginx_repository_url" {
  description = "ECR URL for Magento Nginx image"
  value       = aws_ecr_repository.magento_nginx.repository_url
}

output "app_repository_arn" {
  description = "ARN for Magento app image repository"
  value       = aws_ecr_repository.magento_app.arn
}

output "nginx_repository_arn" {
  description = "ARN for Magento nginx image repository"
  value       = aws_ecr_repository.magento_nginx.arn
}
