output "app_log_group_arn" {
  description = "ARN of the Magento App CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.magento_app.arn
}

output "nginx_log_group_arn" {
  description = "ARN of the Magento Nginx CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.magento_nginx.arn
}
