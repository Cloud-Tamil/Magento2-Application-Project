variable "environment" {
  description = "Environment name"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "123456789012"
}

variable "oidc_provider_arn" {
  description = "OIDC Provider ARN for EKS"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC Provider URL for EKS"
  type        = string
}

variable "tags" {
  description = "Tags map"
  type        = map(string)
  default     = {}
}
