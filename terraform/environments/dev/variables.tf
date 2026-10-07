variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment identifier"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
  default     = "magento-dev-eks"
}

variable "domain_name" {
  description = "Domain name for dev storefront"
  type        = string
  default     = "dev.shop.enterprise-magento.com"
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
