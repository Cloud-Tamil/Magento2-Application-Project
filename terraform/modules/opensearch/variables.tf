variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "123456789012"
}

variable "private_subnet_ids" {
  description = "Private Subnet IDs for OpenSearch VPC deployment"
  type        = list(string)
}

variable "opensearch_security_group_id" {
  description = "Security Group ID for OpenSearch"
  type        = string
}

variable "engine_version" {
  description = "OpenSearch engine version"
  type        = string
  default     = "OpenSearch_2.11"
}

variable "instance_type" {
  description = "OpenSearch cluster instance type"
  type        = string
  default     = "m6g.large.search"
}

variable "instance_count" {
  description = "Number of data instances"
  type        = number
  default     = 2
}

variable "volume_size" {
  description = "EBS storage size in GB"
  type        = number
  default     = 50
}

variable "zone_awareness_enabled" {
  description = "Enable Multi-AZ zone awareness"
  type        = bool
  default     = true
}

variable "availability_zone_count" {
  description = "Number of AZs for zone awareness"
  type        = number
  default     = 2
}

variable "dedicated_master_enabled" {
  description = "Enable dedicated master nodes"
  type        = bool
  default     = false
}

variable "dedicated_master_type" {
  description = "Instance type for dedicated master"
  type        = string
  default     = "m6g.large.search"
}

variable "dedicated_master_count" {
  description = "Count of dedicated master nodes"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Tags map"
  type        = map(string)
  default     = {}
}
