# ==============================================================================
# Security Groups Module - Strict Least Privilege Network Isolation
# ==============================================================================

# 1. Application Load Balancer Security Group (Publicly exposed)
resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "Security group for external Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow inbound HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow inbound HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound to VPC / EKS worker nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.environment}-alb-sg" })
}

# 2. EKS Worker Nodes Security Group
resource "aws_security_group" "eks_nodes" {
  name        = "${var.environment}-eks-nodes-sg"
  description = "Security group for EKS worker nodes and Magento Pods"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow traffic from ALB to EKS NodePort / Pod IPs"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Allow inter-node communication within EKS cluster"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Allow all outbound traffic from worker nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name                                        = "${var.environment}-eks-nodes-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

# 3. RDS MySQL Security Group (Zero public access; only EKS worker nodes)
resource "aws_security_group" "rds" {
  name        = "${var.environment}-rds-mysql-sg"
  description = "Allow MySQL traffic strictly from EKS worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL port 3306 from EKS worker nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.environment}-rds-mysql-sg" })
}

# 4. ElastiCache Redis Security Group (Zero public access; only EKS worker nodes)
resource "aws_security_group" "redis" {
  name        = "${var.environment}-elasticache-redis-sg"
  description = "Allow Redis traffic strictly from EKS worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis port 6379 from EKS worker nodes"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.environment}-elasticache-redis-sg" })
}

# 5. OpenSearch Security Group (Zero public access; only EKS worker nodes)
resource "aws_security_group" "opensearch" {
  name        = "${var.environment}-opensearch-sg"
  description = "Allow OpenSearch HTTPS traffic strictly from EKS worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS port 443 from EKS worker nodes"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.environment}-opensearch-sg" })
}

# 6. Amazon MQ RabbitMQ Security Group (Zero public access; only EKS worker nodes)
resource "aws_security_group" "mq" {
  name        = "${var.environment}-amazon-mq-sg"
  description = "Allow RabbitMQ AMQP/SSL traffic strictly from EKS worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "AMQPS port 5671 from EKS worker nodes"
    from_port       = 5671
    to_port         = 5671
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  ingress {
    description     = "AMQP port 5672 from EKS worker nodes"
    from_port       = 5672
    to_port         = 5672
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.environment}-amazon-mq-sg" })
}

# 7. EFS CSI Shared Media Security Group
resource "aws_security_group" "efs" {
  name        = "${var.environment}-efs-sg"
  description = "Allow NFS port 2049 strictly from EKS worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS port 2049 from EKS nodes"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.environment}-efs-sg" })
}
