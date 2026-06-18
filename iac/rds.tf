# ---------------------------------------------------------------------------
# RDS PostgreSQL 16 — base de datos relacional (pedidos, stock, disponibilidad).
#
# Se elige PostgreSQL (no NoSQL) por la necesidad de consistencia ACID en las
# transacciones de pedidos y el control preciso de inventario por sede.
#
#   - Instancia primaria Multi-AZ en subredes privadas (solo escrituras).
#   - Réplica de lectura para descargar las consultas y servir de fallback
#     de la caché Redis.
#   - Cifrado en reposo con la CMK general; credenciales del password aleatorio
#     que también se publica en SSM Parameter Store.
# ---------------------------------------------------------------------------

variable "db_instance_class" {
  description = "Clase de instancia para RDS PostgreSQL"
  type        = string
  default     = "db.t4g.small"
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnets"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project}-db-subnets"
  }
}

resource "aws_db_parameter_group" "main" {
  name   = "${var.project}-pg16"
  family = "postgres16"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = {
    Name = "${var.project}-pg16"
  }
}

# --- Instancia primaria (escrituras) ---------------------------------------
resource "aws_db_instance" "primary" {
  identifier     = "${var.project}-pg-primary"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.main.arn

  db_name  = "pedidos"
  username = var.db_username
  password = random_password.db.result

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  backup_retention_period   = 7
  backup_window             = "07:00-08:00"
  maintenance_window        = "Mon:08:30-Mon:09:30"
  copy_tags_to_snapshot     = true
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project}-pg-final"

  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.main.arn
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.project}-pg-primary"
    Role = "escritura"
  }
}

# --- Réplica de lectura (lecturas y fallback de caché) ---------------------
resource "aws_db_instance" "replica" {
  identifier          = "${var.project}-pg-replica"
  replicate_source_db = aws_db_instance.primary.identifier
  instance_class      = var.db_instance_class

  storage_encrypted = true
  kms_key_id        = aws_kms_key.main.arn

  vpc_security_group_ids = [aws_security_group.rds.id]

  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.main.arn

  skip_final_snapshot        = true
  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.project}-pg-replica"
    Role = "lectura"
  }
}
