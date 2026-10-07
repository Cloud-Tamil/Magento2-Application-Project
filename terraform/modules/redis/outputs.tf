output "primary_endpoint_address" {
  description = "The address of the endpoint for the primary node in the replication group"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "reader_endpoint_address" {
  description = "The address of the endpoint for the reader nodes in the replication group"
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "port" {
  description = "The port number on which the cache accepts connections"
  value       = aws_elasticache_replication_group.redis.port
}
