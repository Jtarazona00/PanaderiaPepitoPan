# ---------------------------------------------------------------------------
# ECR — repositorios de imágenes Docker (backend Node.js y frontend nginx).
#
# Tags inmutables (evita sobrescribir una imagen ya desplegada), escaneo de
# vulnerabilidades al hacer push y cifrado con la CMK general. Una lifecycle
# policy conserva solo las imágenes más recientes.
#
# ---------------------------------------------------------------------------
# CÓMO SUBIR UNA IMAGEN A ESTOS REPOSITORIOS (manual, desde PowerShell)
# ---------------------------------------------------------------------------
#
#   0) Verificar credenciales y calcular la URL del registro:
#        aws sts get-caller-identity
#        $ACCOUNT  = (aws sts get-caller-identity --query Account --output text)
#        $REGISTRY = "$ACCOUNT.dkr.ecr.us-east-2.amazonaws.com"
#
#   1) Crear los repos si aún no existen (solo la CMK + los repos, sin
#      levantar el resto del stack):
#        terraform apply -target=aws_ecr_repository.this -var="environment=dev"
#
#   2) Autenticar Docker contra ECR:
#        aws ecr get-login-password --region us-east-2 |
#          docker login --username AWS --password-stdin $REGISTRY
#
#   3) Construir la imagen (desde la raíz del repositorio):
#        docker build -t pepito-pan/backend:v1 ./docker/backend
#
#   4) Etiquetarla hacia ECR:
#        docker tag pepito-pan/backend:v1 "$REGISTRY/pepito-pan/backend:v1"
#
#   5) Subirla (aquí se dispara el scan_on_push definido abajo):
#        docker push "$REGISTRY/pepito-pan/backend:v1"
#
#   6) Verificar que llegó:
#        aws ecr list-images --repository-name pepito-pan/backend --region us-east-2
#
#   7) Limpiar para no incurrir en costos:
#        aws ecr batch-delete-image --repository-name pepito-pan/backend
#          --region us-east-2 --image-ids imageTag=v1
#
#   Notas:
#     - Por image_tag_mutability = IMMUTABLE cada push necesita un tag NUEVO
#       (v1, v2, ... o el SHA del commit); no se puede re-subir el mismo tag.
#     - Para el frontend es idéntico: cambiar backend -> frontend y
#       ./docker/backend -> ./docker/frontend.
#     - En CI este mismo flujo está automatizado en
#       .github/workflows/build-push-ecr.yml
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
