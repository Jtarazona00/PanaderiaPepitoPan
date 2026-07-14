# ---------------------------------------------------------------------------
# SES — envío del correo de alerta.
#
# La "Lambda Error" usa SES para enviar el aviso por correo a los
# administradores de las 350 sedes cuando detecta un fallo en la plataforma.
#
# SES exige verificar la identidad del remitente antes de poder enviar. Si no
# se define un remitente (var.ses_sender_email vacío) no se crea el recurso,
# de modo que el resto de la infraestructura pueda desplegarse igual.
# ---------------------------------------------------------------------------

variable "ses_sender_email" {
  description = "Correo remitente verificado en SES (vacío = no se crea la identidad)"
  type        = string
  default     = ""
}

resource "aws_ses_email_identity" "sender" {
  count = var.ses_sender_email == "" ? 0 : 1

  email = var.ses_sender_email
}
