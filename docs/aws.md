# AWS Infrastructure Architecture Guide

## AWS Service Mapping

| Component | AWS Managed Service | Configuration Details |
|---|---|---|
| Networking | AWS VPC | 3 Availability Zones, Public + Private App + Private DB Subnets, Multi-AZ NAT Gateways |
| Container Orchestration | Amazon EKS (v1.30) | Managed Node Groups in Private Subnets, IRSA / Pod Identity, EBS CSI Driver, CoreDNS |
| Ingress / Load Balancing | AWS Application Load Balancer | Automated via AWS Load Balancer Controller, SSL Redirect, ACM TLS 1.2+ |
| Container Registry | Amazon ECR | Private repos, KMS encryption, scan on push, lifecycle rules |
| Database | Amazon RDS MySQL (8.0) | Multi-AZ standby, private DB subnet, automated daily snapshots, storage autoscaling |
| Cache & Sessions | Amazon ElastiCache Redis (7.1) | Multi-AZ replication group with automatic failover, cluster mode, in-transit encryption |
| Catalog Search Engine | Amazon OpenSearch Service (2.11) | VPC deployed, 3 dedicated master nodes, 3 data nodes across 3 AZs |
| Message Queuing | Amazon MQ for RabbitMQ (3.13) | Active/standby or multi-AZ cluster broker, TLS encryption on port 5671 |
| Secrets Vault | AWS Secrets Manager | Zero plaintext secrets in Git; automated random password generation & rotation |
| Shared Media Storage | AWS EFS (Elastic File System) | EFS CSI Driver, ReadWriteMany persistent volume for `pub/media` |
| Monitoring & Logs | Amazon CloudWatch | Container Insights, structured JSON logging, alarm on RDS CPU > 80% and Redis memory > 85% |
| DNS & Certificates | AWS Route 53 & ACM | Public hosted zone, automated DNS-01 validation |

## Security Highlights
- **Private Worker Nodes**: All EKS worker nodes run inside private application subnets. Direct SSH / public IP allocation is disabled.
- **Strict Security Group Ingress**: RDS, Redis, OpenSearch, and Amazon MQ only accept traffic from the EKS Worker Nodes Security Group (`eks_nodes_sg`).
- **Least Privilege IAM**: Pods use IAM Roles for Service Accounts (IRSA) to obtain short-lived STS tokens for AWS Secrets Manager and S3 access without storing AWS Access Keys inside containers.
