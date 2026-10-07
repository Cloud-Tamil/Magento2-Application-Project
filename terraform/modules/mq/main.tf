# ==============================================================================
# Amazon MQ Module - Fully Managed RabbitMQ for Magento Message Queues
# ==============================================================================

resource "aws_mq_broker" "rabbitmq" {
  broker_name        = "${var.environment}-magento-rabbitmq"
  engine_type        = "RabbitMQ"
  engine_version     = var.engine_version
  host_instance_type = var.host_instance_type
  deployment_mode    = var.deployment_mode

  subnet_ids          = var.deployment_mode == "CLUSTER_MULTI_AZ" ? var.private_subnet_ids : [var.private_subnet_ids[0]]
  security_groups     = [var.mq_security_group_id]
  publicly_accessible = false

  user {
    username = var.mq_admin_username
    password = var.mq_admin_password
  }

  auto_minor_version_upgrade = true
  maintenance_window_start_time {
    day_of_week = "SUNDAY"
    time_of_day = "04:00"
    time_zone   = "UTC"
  }

  tags = merge(var.tags, { Name = "${var.environment}-magento-rabbitmq" })
}
