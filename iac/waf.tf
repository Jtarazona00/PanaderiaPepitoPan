# ---------------------------------------------------------------------------
# WAF v2 — se adjunta al ALB (no al API Gateway).
#
# Tres líneas de defensa:
#   1. Conjunto de reglas comunes administradas por AWS (OWASP Top 10).
#   2. Conjunto específico contra inyección SQL (SQLi).
#   3. Regla de tasa: bloquea las IPs que superan 2000 solicitudes.
#
# La asociación del Web ACL con el ALB se define junto al ALB (capa de cómputo).
# ---------------------------------------------------------------------------

resource "aws_wafv2_web_acl" "alb" {
  name        = "${var.project}-alb-waf"
  description = "Proteccion del ALB: OWASP, SQLi y limite de tasa por IP"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # 1. Reglas comunes administradas por AWS (OWASP)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-common"
      sampled_requests_enabled   = true
    }
  }

  # 2. Proteccion especifica contra inyeccion SQL
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # 3. Limite de tasa: bloquea IPs que superan 2000 solicitudes
  rule {
    name     = "RateLimitPerIP"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-ratelimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project}-alb-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.project}-alb-waf"
  }
}
