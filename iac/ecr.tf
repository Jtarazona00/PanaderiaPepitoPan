# ---------------------------------------------------------------------------
# ECR — repositorios de imágenes Docker (backend Node.js y frontend nginx).
#
# Tags inmutables (evita sobrescribir una imagen ya desplegada), escaneo de
# vulnerabilidades al hacer push y cifrado con la CMK general. Una lifecycle
# policy conserva solo las imágenes más recientes.
# ---------------------------------------------------------------------------

locals {
  ecr_repositories = ["backend", "frontend"]
}

resource "aws_ecr_repository" "this" {
  for_each = toset(local.ecr_repositories)

  name                 = "${var.project}/${each.key}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.main.arn
  }

  tags = {
    Name = "${var.project}-${each.key}"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Conservar solo las ultimas 10 imagenes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
