# ---------------------------------------------------------------------------
# IAM — control de acceso por rol con privilegio mínimo.
#
# Dos grupos de personas:
#   - Admins    -> AdministratorAccess (full restringido por organización).
#   - Operators -> PowerUserAccess (operación sin gestión de IAM/cuenta).
#
# Roles de servicio para las tareas ECS Fargate: el rol de ejecución descarga
# imágenes de ECR, publica logs y lee credenciales de SSM; el rol de tarea
# concentra los permisos de la aplicación en runtime.
# ---------------------------------------------------------------------------

# --- Grupos de usuarios ----------------------------------------------------
resource "aws_iam_group" "admins" {
  name = "${var.project}-admins"
}

resource "aws_iam_group_policy_attachment" "admins" {
  group      = aws_iam_group.admins.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_group" "operators" {
  name = "${var.project}-operators"
}

resource "aws_iam_group_policy_attachment" "operators" {
  group      = aws_iam_group.operators.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# --- Confianza común para las tareas ECS -----------------------------------
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# --- Rol de ejecución de tareas (infraestructura del contenedor) -----------
resource "aws_iam_role" "ecs_execution" {
  name               = "${var.project}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Lectura de credenciales SecureString en SSM y descifrado con la CMK general.
data "aws_iam_policy_document" "ecs_secrets" {
  statement {
    sid    = "ReadSsmParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = ["arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/*"]
  }

  statement {
    sid       = "DecryptWithKms"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.main.arn]
  }
}

resource "aws_iam_role_policy" "ecs_secrets" {
  name   = "${var.project}-ecs-secrets"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.ecs_secrets.json
}

# --- Rol de la tarea (permisos de la aplicación en runtime) ----------------
resource "aws_iam_role" "ecs_task" {
  name               = "${var.project}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}
