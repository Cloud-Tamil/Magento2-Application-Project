output "endpoint" {
  description = "Domain-specific endpoint used to submit index, search, and data upload requests"
  value       = aws_opensearch_domain.opensearch.endpoint
}

output "domain_name" {
  description = "The name of the OpenSearch domain"
  value       = aws_opensearch_domain.opensearch.domain_name
}

output "arn" {
  description = "The ARN of the OpenSearch domain"
  value       = aws_opensearch_domain.opensearch.arn
}
