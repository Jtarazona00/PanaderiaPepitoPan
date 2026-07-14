# ---------------------------------------------------------------------------
# Security Groups por capa. El tráfico fluye en un solo sentido:
#
#   Internet --443--> ALB --8080--> ECS --5432--> RDS
#                                       \--6379--> Redis
#
# Cada capa solo acepta conexiones de la capa inmediatamente anterior,
# referenciando su security group en lugar de rangos de IP.
# ---------------------------------------------------------------------------

# --- ALB: acepta HTTPS público ---------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "Permite HTTPS entrante hacia el ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS desde internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Salida hacia las tareas ECS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-alb-sg"
  }
}

# --- ECS: solo recibe tráfico del ALB --------------------------------------
resource "aws_security_group" "ecs" {
  name        = "${var.project}-ecs-sg"
  description = "Tareas ECS Fargate (frontend nginx y backend Node.js)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Trafico de aplicacion desde el ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Salida a internet via NAT y a los servicios internos"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-ecs-sg"
  }
}

# --- RDS: solo acepta PostgreSQL desde ECS ---------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "PostgreSQL accesible unicamente desde las tareas ECS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL desde ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    description = "Respuestas hacia las tareas ECS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-rds-sg"
  }
}

# --- Redis: solo acepta 6379 desde ECS -------------------------------------
resource "aws_security_group" "redis" {
  name        = "${var.project}-redis-sg"
  description = "ElastiCache Redis accesible unicamente desde las tareas ECS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis desde ECS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    description = "Respuestas hacia las tareas ECS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-redis-sg"
  }
}

# --- Fix CKV2_AWS_12: restringir el default security group -----------------
# El security group por defecto de la VPC se deja SIN reglas de ingress ni
# egress, de modo que no permita ningun trafico. Ningun recurso lo usa: cada
# capa tiene su propio security group definido arriba.
resource "aws_default_security_group" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-default-sg-restringido"
  }
}
