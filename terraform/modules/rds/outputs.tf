output "endpoint" {
  description = "Connection endpoint for the RDS instance"
  value       = aws_db_instance.rds.endpoint
}

output "address" {
  description = "Hostname of the RDS instance"
  value       = aws_db_instance.rds.address
}

output "port" {
  description = "Port of the RDS instance"
  value       = aws_db_instance.rds.port
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.rds.db_name
}

output "resource_id" {
  description = "The RDS Resource ID of this instance"
  value       = aws_db_instance.rds.resource_id
}
