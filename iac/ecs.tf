# ---------------------------------------------------------------------------
# ECS Fargate — frontend (nginx) y backend (Node.js) repartidos en las 3 AZ.
#
#   - Auto Scaling reactivo: escala cuando la CPU promedio supera el 65%.
#   - Scheduled Scaling: asegura capacidad ANTES de los picos
#     (10:00 apertura, 12:30 pre-almuerzo, 19:00 pre-cena) y reduce al mínimo
#     en la noche (23:00 night-mode) para optimizar costos.
#   - Backend: min 4 / max 20 tasks. Frontend: min 4 / max 12 tasks.
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# --- Grupos de logs (cifrados con la CMK de logs) --------------------------
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project}/frontend"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project}/backend"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}

# --- Task definitions ------------------------------------------------------
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "${aws_ecr_repository.this["frontend"].repository_url}:latest"
      essential = true
      portMappings = [
        { containerPort = 8080, protocol = "tcp" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "frontend"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.this["backend"].repository_url}:latest"
      essential = true
      portMappings = [
        { containerPort = 8080, protocol = "tcp" }
      ]
      secrets = [
        { name = "DB_USERNAME", valueFrom = aws_ssm_parameter.db_username.arn },
        { name = "DB_PASSWORD", valueFrom = aws_ssm_parameter.db_password.arn }
      ]
      environment = [
        { name = "DB_HOST", value = aws_db_instance.primary.address },
        { name = "DB_REPLICA_HOST", value = aws_db_instance.replica.address },
        { name = "REDIS_HOST", value = aws_elasticache_replication_group.main.primary_endpoint_address }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend"
        }
      }
    }
  ])
}

# --- Servicios -------------------------------------------------------------
resource "aws_ecs_service" "frontend" {
  name            = "${var.project}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 4
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.https]
}

resource "aws_ecs_service" "backend" {
  name            = "${var.project}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 4
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.https]
}

# --- Auto Scaling reactivo (objetivo CPU 65%) ------------------------------
resource "aws_appautoscaling_target" "frontend" {
  max_capacity       = 12
  min_capacity       = 4
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.frontend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "frontend_cpu" {
  name               = "${var.project}-frontend-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.frontend.resource_id
  scalable_dimension = aws_appautoscaling_target.frontend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.frontend.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 65
  }
}

resource "aws_appautoscaling_target" "backend" {
  max_capacity       = 20
  min_capacity       = 4
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "backend_cpu" {
  name               = "${var.project}-backend-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.backend.resource_id
  scalable_dimension = aws_appautoscaling_target.backend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.backend.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 65
  }
}

# --- Scheduled Scaling (horarios en zona America/Lima, mar-dom) ------------
locals {
  backend_schedules = {
    open       = { schedule = "cron(0 10 ? * TUE-SUN *)", min = 4, max = 20 }
    pre_lunch  = { schedule = "cron(30 12 ? * TUE-SUN *)", min = 10, max = 20 }
    pre_dinner = { schedule = "cron(0 19 ? * TUE-SUN *)", min = 10, max = 20 }
    night_mode = { schedule = "cron(0 23 ? * TUE-SUN *)", min = 1, max = 4 }
  }

  frontend_schedules = {
    open       = { schedule = "cron(0 10 ? * TUE-SUN *)", min = 4, max = 12 }
    pre_lunch  = { schedule = "cron(30 12 ? * TUE-SUN *)", min = 8, max = 12 }
    pre_dinner = { schedule = "cron(0 19 ? * TUE-SUN *)", min = 8, max = 12 }
    night_mode = { schedule = "cron(0 23 ? * TUE-SUN *)", min = 1, max = 4 }
  }
}

resource "aws_appautoscaling_scheduled_action" "backend" {
  for_each = local.backend_schedules

  name               = each.key
  service_namespace  = aws_appautoscaling_target.backend.service_namespace
  resource_id        = aws_appautoscaling_target.backend.resource_id
  scalable_dimension = aws_appautoscaling_target.backend.scalable_dimension
  schedule           = each.value.schedule
  timezone           = "America/Lima"

  scalable_target_action {
    min_capacity = each.value.min
    max_capacity = each.value.max
  }
}

resource "aws_appautoscaling_scheduled_action" "frontend" {
  for_each = local.frontend_schedules

  name               = each.key
  service_namespace  = aws_appautoscaling_target.frontend.service_namespace
  resource_id        = aws_appautoscaling_target.frontend.resource_id
  scalable_dimension = aws_appautoscaling_target.frontend.scalable_dimension
  schedule           = each.value.schedule
  timezone           = "America/Lima"

  scalable_target_action {
    min_capacity = each.value.min
    max_capacity = each.value.max
  }
}
