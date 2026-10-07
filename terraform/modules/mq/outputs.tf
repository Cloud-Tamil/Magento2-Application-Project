output "broker_id" {
  description = "The unique ID of the Amazon MQ RabbitMQ broker"
  value       = aws_mq_broker.rabbitmq.id
}

output "broker_arn" {
  description = "The ARN of the broker"
  value       = aws_mq_broker.rabbitmq.arn
}

output "amqp_ssl_endpoint" {
  description = "AMQP SSL endpoint connection URL"
  value       = length(aws_mq_broker.rabbitmq.instances) > 0 ? aws_mq_broker.rabbitmq.instances[0].endpoints[0] : ""
}
