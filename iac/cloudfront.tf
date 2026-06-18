# ---------------------------------------------------------------------------
# CloudFront — CDN frente al API Gateway.
#
# El menú unificado se sirve desde caché (TTL 300s) para las 350 sedes a la
# vez, reduciendo la latencia y la carga sobre el backend. Todo el tráfico de
# visor se fuerza a HTTPS y los logs de acceso van al bucket S3 de logs.
# ---------------------------------------------------------------------------

locals {
  api_origin_domain = replace(aws_apigatewayv2_api.main.api_endpoint, "https://", "")
}

resource "aws_cloudfront_distribution" "main" {
  enabled         = true
  comment         = "${var.project} - CDN de la plataforma de pedidos"
  price_class     = "PriceClass_100"
  is_ipv6_enabled = true

  origin {
    domain_name = local.api_origin_domain
    origin_id   = "apigw"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "apigw"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    # TTL del menú: 5 minutos
    default_ttl = 300
    min_ttl     = 0
    max_ttl     = 600

    forwarded_values {
      query_string = true

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  logging_config {
    bucket          = aws_s3_bucket.logs.bucket_domain_name
    prefix          = "cloudfront"
    include_cookies = false
  }

  tags = {
    Name = "${var.project}-cdn"
  }
}
