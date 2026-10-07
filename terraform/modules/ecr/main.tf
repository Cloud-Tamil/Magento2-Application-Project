# ==============================================================================
# ECR Module - Encrypted Container Registries with Vulnerability Scanning
# ==============================================================================

# 1. Magento Application Image Repository (PHP-FPM)
resource "aws_ecr_repository" "magento_app" {
  name                 = "${var.environment}-magento2-app"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = var.tags
}

# 2. Magento Nginx Web Server Repository
resource "aws_ecr_repository" "magento_nginx" {
  name                 = "${var.environment}-magento2-nginx"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = var.tags
}

# Lifecycle Policy: Keep only the latest 30 images to conserve storage cost
resource "aws_ecr_lifecycle_policy" "app_policy" {
  repository = aws_ecr_repository.magento_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Retain latest 30 releases"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release", "prod", "staging", "dev"]
          countType     = "imageCount"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "nginx_policy" {
  repository = aws_ecr_repository.magento_nginx.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
