variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "magento2-devops"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "tags" {
  description = "Tags map"
  type        = map(string)
  default     = {}
}
