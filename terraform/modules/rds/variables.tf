variable "environment" {
  description = "Environment name"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private Subnet IDs for RDS Subnet Group"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "Security Group ID for RDS"
  type        = string
}

variable "database_name" {
  description = "Name of the MySQL database"
  type        = string
  default     = "magento2"
}

variable "database_user" {
  description = "Master MySQL database username"
  type        = string
  default     = "magento_db_admin"
}

variable "database_password" {
  description = "Master MySQL database password (passed from AWS Secrets Manager or variable)"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS Instance class"
  type        = string
  default     = "db.m6g.large"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 50
}

variable "max_allocated_storage" {
  description = "Maximum storage autoscaling limit in GB"
  type        = number
  default     = 500
}

variable "iops" {
  description = "Allocated IOPS for gp3 storage"
  type        = number
  default     = 3000
}

variable "storage_throughput" {
  description = "Storage throughput in MB/s for gp3"
  type        = number
  default     = 125
}

variable "multi_az" {
  description = "Enable Multi-AZ high availability"
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Automated backup retention in days"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Protect database from accidental deletion"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS Key ARN for storage encryption"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags map"
  type        = map(string)
  default     = {}
}
