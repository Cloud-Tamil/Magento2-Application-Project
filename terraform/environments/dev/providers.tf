terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Backend configuration for remote S3 state and DynamoDB lock
  # Note: Run 'terraform init -backend-config="bucket=..."' or uncomment after s3-state creation
  # backend "s3" {
  #   bucket         = "magento2-devops-terraform-state-123456789012"
  #   key            = "dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "magento2-devops-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "magento2-devops"
      ManagedBy   = "Terraform"
    }
  }
}
