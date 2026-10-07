variable "environment" {
  description = "Environment name"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private Subnet IDs"
  type        = list(string)
}

variable "mq_security_group_id" {
  description = "Security Group ID for Amazon MQ"
  type        = string
}

variable "engine_version" {
  description = "RabbitMQ engine version"
  type        = string
  default     = "3.13"
}

variable "host_instance_type" {
  description = "Broker instance type"
  type        = string
  default     = "mq.m5.large"
}

variable "deployment_mode" {
  description = "Deployment mode: SINGLE_INSTANCE or CLUSTER_MULTI_AZ"
  type        = string
  default     = "CLUSTER_MULTI_AZ"
}

variable "mq_admin_username" {
  description = "RabbitMQ master user"
  type        = string
  default     = "magento_admin"
}

variable "mq_admin_password" {
  description = "RabbitMQ master password"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags map"
  type        = map(string)
  default     = {}
}
