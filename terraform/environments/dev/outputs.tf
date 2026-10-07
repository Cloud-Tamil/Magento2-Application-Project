output "eks_cluster_name" {
  description = "EKS Cluster Name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS Cluster Endpoint"
  value       = module.eks.cluster_endpoint
}

output "ecr_app_url" {
  description = "ECR App Repository URL"
  value       = module.ecr.app_repository_url
}

output "ecr_nginx_url" {
  description = "ECR Nginx Repository URL"
  value       = module.ecr.nginx_repository_url
}

output "rds_endpoint" {
  description = "RDS MySQL Host"
  value       = module.rds.address
}

output "redis_endpoint" {
  description = "Redis Cache Host"
  value       = module.redis.primary_endpoint_address
}

output "opensearch_endpoint" {
  description = "OpenSearch Endpoint"
  value       = module.opensearch.endpoint
}

output "mq_endpoint" {
  description = "RabbitMQ AMQP SSL Endpoint"
  value       = module.mq.amqp_ssl_endpoint
}
