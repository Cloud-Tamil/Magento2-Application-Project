# ==============================================================================
# CloudWatch Module - Centralized Logging & Enterprise Alerting
# ==============================================================================

# Application Log Group for Kubernetes Container Insights
resource "aws_cloudwatch_log_group" "magento_app" {
  name              = "/aws/containerinsights/${var.cluster_name}/magento-app"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Nginx Web Access and Error Log Group
resource "aws_cloudwatch_log_group" "magento_nginx" {
  name              = "/aws/containerinsights/${var.cluster_name}/magento-nginx"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Alarm: RDS CPU Utilization > 80%
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  alarm_name          = "${var.environment}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This alarm fires if RDS MySQL CPU exceeds 80% for 10 minutes"
  dimensions = {
    DBInstanceIdentifier = "${var.environment}-magento-rds"
  }
  tags = var.tags
}

# Alarm: ElastiCache Redis High Memory (> 85%)
resource "aws_cloudwatch_metric_alarm" "redis_high_memory" {
  alarm_name          = "${var.environment}-redis-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "This alarm fires if Redis Memory Usage exceeds 85%"
  dimensions = {
    CacheClusterId = "${var.environment}-magento-redis-001"
  }
  tags = var.tags
}
