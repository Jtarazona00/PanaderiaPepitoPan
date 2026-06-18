# ---------------------------------------------------------------------------
# Route 53 — DNS público de la plataforma.
#
# Si no se define un dominio (var.domain_name vacío) no se crea ningún recurso
# de DNS, de modo que el resto de la infraestructura puede desplegarse sin un
# dominio registrado.
# ---------------------------------------------------------------------------

variable "domain_name" {
  description = "Dominio público de la plataforma (vacío = no se crean recursos DNS)"
  type        = string
  default     = ""
}

resource "aws_route53_zone" "main" {
  count = var.domain_name == "" ? 0 : 1

  name = var.domain_name

  tags = {
    Name = "${var.project}-zone"
  }
}

resource "aws_route53_record" "root" {
  count = var.domain_name == "" ? 0 : 1

  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}
