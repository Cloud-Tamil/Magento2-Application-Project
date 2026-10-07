variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "123456789012"
}

variable "oidc_provider_arn" {
  description = "EKS OIDC Provider ARN for IRSA"
  type        = string
  default     = ""
}

variable "oidc_provider_url" {
  description = "EKS OIDC Provider URL for IRSA"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags map"
  type        = map(string)
  default     = {}
}
