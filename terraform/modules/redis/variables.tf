variable "environment" {
  description = "Environment name"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private Subnet IDs for Redis"
  type        = list(string)
}

variable "redis_security_group_id" {
  description = "Security Group ID for Redis"
  type        = string
}

variable "node_type" {
  description = "Instance type for ElastiCache Redis nodes"
  type        = string
  default     = "cache.m6g.large"
}

variable "num_cache_clusters" {
  description = "Number of cache clusters (nodes) in the replication group"
  type        = number
  default     = 2
}

variable "automatic_failover_enabled" {
  description = "Enable automatic failover across AZs"
  type        = bool
  default     = true
}

variable "multi_az_enabled" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Enable in-transit encryption (TLS)"
  type        = bool
  default     = false
}

variable "auth_token" {
  description = "Auth token / password if transit encryption is enabled"
  type        = string
  default     = null
  sensitive   = true
}

variable "snapshot_retention_limit" {
  description = "Number of days for snapshot retention"
  type        = number
  default     = 5
}

variable "tags" {
  description = "Tags map"
  type        = map(string)
  default     = {}
}
