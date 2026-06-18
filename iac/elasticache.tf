# ---------------------------------------------------------------------------
# ElastiCache Redis — caché de lectura.
#
# Complementa a PostgreSQL (no lo reemplaza): sirve el menú unificado y la
# disponibilidad por sede para resolver las consultas sin tocar la base de
# datos en condiciones normales.
#   - TTL menú global: 300s · TTL disponibilidad por sede: 180s (gestionados
#     por la aplicación).
#   - Cifrado en reposo (CMK general) y en tránsito.
# ---------------------------------------------------------------------------

variable "redis_node_type" {
  description = "Tipo de nodo para ElastiCache Redis"
  type        = string
  default     = "cache.t4g.small"
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-redis-subnets"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project}-redis"
  description          = "Cache Redis para menu unificado y disponibilidad por sede"

  engine         = "redis"
  engine_version = "7.1"
  node_type      = var.redis_node_type
  port           = 6379

  num_cache_clusters = 1

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.main.arn
  transit_encryption_enabled = true

  automatic_failover_enabled = false
  multi_az_enabled           = false

  snapshot_retention_limit = 5
  snapshot_window          = "05:00-06:00"
  maintenance_window       = "mon:06:30-mon:07:30"

  apply_immediately = true

  tags = {
    Name = "${var.project}-redis"
  }
}
