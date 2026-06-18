# ---------------------------------------------------------------------------
# ALB — balanceador de aplicación. Recibe el tráfico de API Gateway/CloudFront
# y lo reparte entre las tareas ECS de frontend y backend.
#
# El WAF v2 se asocia directamente al ALB (no al API Gateway). Los logs de
# acceso se entregan al bucket S3 de logs.
# ---------------------------------------------------------------------------

variable "acm_certificate_arn" {
  description = "ARN del certificado ACM para el listener HTTPS del ALB"
  type        = string
  default     = ""
}

resource "aws_lb" "main" {
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  drop_invalid_header_fields = true
  enable_deletion_protection = true

  access_logs {
    bucket  = aws_s3_bucket.logs.id
    prefix  = "alb"
    enabled = true
  }

  tags = {
    Name = "${var.project}-alb"
  }
}

# --- Asociación del WAF v2 al ALB ------------------------------------------
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.alb.arn
}

# --- Target groups ---------------------------------------------------------
resource "aws_lb_target_group" "frontend" {
  name        = "${var.project}-tg-frontend"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project}-tg-frontend"
  }
}

resource "aws_lb_target_group" "backend" {
  name        = "${var.project}-tg-backend"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project}-tg-backend"
  }
}

# --- Listener HTTPS (443): por defecto al frontend -------------------------
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# Las rutas de la API se enrutan al backend
resource "aws_lb_listener_rule" "backend_api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/menu", "/stock/*", "/disponibilidad/*", "/pedidos", "/pedidos/*"]
    }
  }
}

# --- Listener HTTP (80): redirige a HTTPS ----------------------------------
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
