# ---------------------------------------------------------------------------
# SSM Parameter Store — credenciales de la base de datos.
#
# Se guardan como SecureString cifrado con la CMK general (KMS). Las tareas
# ECS las leen al arrancar (vía el rol de ejecución), de modo que nunca
# aparecen en texto plano en las variables de entorno de los contenedores.
# ---------------------------------------------------------------------------

variable "db_username" {
  description = "Usuario maestro de la base de datos PostgreSQL"
  type        = string
  default     = "pepito_admin"
}

# La contraseña se genera aleatoriamente; es la fuente de verdad que consumen
# tanto RDS como el parámetro SecureString.
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#%*-_"
}

resource "aws_ssm_parameter" "db_username" {
  name        = "/${var.project}/db/username"
  description = "Usuario maestro de RDS PostgreSQL"
  type        = "SecureString"
  key_id      = aws_kms_key.main.key_id
  value       = var.db_username

  tags = {
    Name = "${var.project}-db-username"
  }
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.project}/db/password"
  description = "Contraseña maestra de RDS PostgreSQL"
  type        = "SecureString"
  key_id      = aws_kms_key.main.key_id
  value       = random_password.db.result

  tags = {
    Name = "${var.project}-db-password"
  }
}
