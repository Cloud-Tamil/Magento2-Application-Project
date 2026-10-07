output "alb_security_group_id" {
  description = "Security Group ID for ALB"
  value       = aws_security_group.alb.id
}

output "eks_nodes_security_group_id" {
  description = "Security Group ID for EKS worker nodes"
  value       = aws_security_group.eks_nodes.id
}

output "rds_security_group_id" {
  description = "Security Group ID for RDS MySQL"
  value       = aws_security_group.rds.id
}

output "redis_security_group_id" {
  description = "Security Group ID for ElastiCache Redis"
  value       = aws_security_group.redis.id
}

output "opensearch_security_group_id" {
  description = "Security Group ID for OpenSearch"
  value       = aws_security_group.opensearch.id
}

output "mq_security_group_id" {
  description = "Security Group ID for Amazon MQ RabbitMQ"
  value       = aws_security_group.mq.id
}

output "efs_security_group_id" {
  description = "Security Group ID for EFS shared media"
  value       = aws_security_group.efs.id
}
