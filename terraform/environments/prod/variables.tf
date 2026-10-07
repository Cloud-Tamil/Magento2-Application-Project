variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment identifier"
  type        = string
  default     = "prod"
}

variable "cluster_name" {
  description = "Production EKS Cluster Name"
  type        = string
  default     = "magento-prod-eks"
}

variable "domain_name" {
  description = "Production domain name for Magento storefront"
  type        = string
  default     = "shop.enterprise-magento.com"
}

variable "route53_zone_id" {
  description = "Route 53 Hosted Zone ID"
  type        = string
  default     = "Z123456789EXAMPLE"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "123456789012"
}
