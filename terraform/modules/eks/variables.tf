variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes Version"
  type        = string
  default     = "1.30"
}

variable "cluster_role_arn" {
  description = "IAM Role ARN for the EKS Cluster"
  type        = string
}

variable "node_role_arn" {
  description = "IAM Role ARN for the EKS Worker Node Groups"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private Subnet IDs where worker nodes run"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public Subnet IDs for control plane communication"
  type        = list(string)
}

variable "node_security_group_id" {
  description = "Security Group ID for EKS nodes"
  type        = string
}

variable "desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 3
}

variable "min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 10
}

variable "instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["c6i.xlarge", "m6i.xlarge"]
}

variable "capacity_type" {
  description = "Capacity type: ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "disk_size" {
  description = "Root disk size in GB"
  type        = number
  default     = 80
}

variable "tags" {
  description = "Tags map"
  type        = map(string)
  default     = {}
}
