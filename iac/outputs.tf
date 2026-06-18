# ---------------------------------------------------------------------------
# Outputs de la plataforma. Los endpoints de datos se marcan como sensibles;
# no se exponen credenciales en claro (viven en SSM como SecureString).
# ---------------------------------------------------------------------------

output "alb_dns_name" {
  description = "DNS del Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "cloudfront_domain" {
  description = "Dominio de la distribución CloudFront"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "apigw_endpoint" {
  description = "Endpoint del API Gateway HTTP v2"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "rds_primary_endpoint" {
  description = "Endpoint de escritura de RDS PostgreSQL"
  value       = aws_db_instance.primary.endpoint
  sensitive   = true
}

output "rds_replica_endpoint" {
  description = "Endpoint de lectura de RDS PostgreSQL"
  value       = aws_db_instance.replica.endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "Endpoint primario de ElastiCache Redis"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
  sensitive   = true
}

output "ecr_repository_urls" {
  description = "URLs de los repositorios ECR (backend y frontend)"
  value       = { for k, repo in aws_ecr_repository.this : k => repo.repository_url }
}

output "sns_alerts_topic_arn" {
  description = "ARN del topic SNS de alertas"
  value       = aws_sns_topic.alerts.arn
}

output "sqs_queue_url" {
  description = "URL de la cola SQS de errores"
  value       = aws_sqs_queue.main.url
}
