# ---------------------------------------------------------------------------
# API Gateway HTTP v2 — capa entre CloudFront y el ALB.
#
# Integra de forma privada con el ALB a través de un VPC Link. El stage
# registra logs de acceso en un grupo de CloudWatch cifrado y aplica límites
# de throttling para proteger el backend.
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project}-http-api"
  protocol_type = "HTTP"
  description   = "API de la plataforma de pedidos"
}

resource "aws_cloudwatch_log_group" "apigw" {
  name              = "/apigw/${var.project}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}

# --- VPC Link hacia las subredes privadas ----------------------------------
resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "${var.project}-vpclink"
  security_group_ids = [aws_security_group.alb.id]
  subnet_ids         = aws_subnet.private[*].id

  tags = {
    Name = "${var.project}-vpclink"
  }
}

resource "aws_apigatewayv2_integration" "alb" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = aws_lb_listener.https.arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }

  default_route_settings {
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
  }
}
