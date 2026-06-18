# ---------------------------------------------------------------------------
# Bucket S3 para los logs de acceso del ALB y de CloudFront.
#
# TODO: pendiente endurecer en una iteración posterior (bloqueo de acceso
# público, versionado y cifrado en reposo) antes de pasar a producción.
# ---------------------------------------------------------------------------

resource "random_id" "logs_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "logs" {
  bucket = "${var.project}-access-logs-${random_id.logs_suffix.hex}"

  tags = {
    Name    = "${var.project}-access-logs"
    Purpose = "alb-cloudfront-access-logs"
  }
}
