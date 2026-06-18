# ---------------------------------------------------------------------------
# SNS — alertas al administrador.
#
# Las alarmas de CloudWatch y la Lambda de manejo de errores publican en este
# topic, que reenvía por correo al administrador (notificación en < 30s).
# El topic está cifrado con la CMK general.
# ---------------------------------------------------------------------------

variable "admin_email" {
  description = "Correo del administrador para las alertas (vacío = sin suscripción)"
  type        = string
  default     = ""
}

resource "aws_sns_topic" "alerts" {
  name              = "${var.project}-alertas"
  kms_master_key_id = aws_kms_key.main.arn

  tags = {
    Name = "${var.project}-alertas"
  }
}

resource "aws_sns_topic_subscription" "admin_email" {
  count = var.admin_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.admin_email
}
