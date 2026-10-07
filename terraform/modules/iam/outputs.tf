output "eks_cluster_role_arn" {
  description = "ARN of the EKS Cluster control plane role"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_nodes_role_arn" {
  description = "ARN of the EKS Worker Nodes role"
  value       = aws_iam_role.eks_nodes.arn
}

output "magento_pod_irsa_role_arn" {
  description = "ARN of the IAM role for Magento Pod ServiceAccount"
  value       = aws_iam_role.magento_pod_irsa.arn
}
