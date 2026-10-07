variable "environment" {
  description = "Environment name"
  type        = string
}

variable "database_user" {
  description = "Master MySQL database username"
  type        = string
  default     = "magento_db_user"
}

variable "database_name" {
  description = "Database name"
  type        = string
  default     = "magento2"
}

variable "mq_user" {
  description = "RabbitMQ username"
  type        = string
  default     = "magento_mq_user"
}

variable "admin_user" {
  description = "Magento Admin UI username"
  type        = string
  default     = "enterprise_admin"
}

variable "tags" {
  description = "Tags map"
  type        = map(string)
  default     = {}
}
