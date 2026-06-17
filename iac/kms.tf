# ---------------------------------------------------------------------------
# KMS — cifrado transversal de la plataforma.
#
# La CMK "main" cifra en reposo: RDS, ElastiCache, SQS, ECR, SSM Parameter
# Store, el vault de AWS Backup y las variables de entorno de Lambda.
# La CMK "logs" se dedica a los grupos de CloudWatch Logs, que requieren una
# política de clave que autorice explícitamente al servicio de logs.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# --- CMK general -----------------------------------------------------------
resource "aws_kms_key" "main" {
  description             = "CMK general (RDS, ElastiCache, SQS, ECR, SSM, Backup, Lambda)"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "${var.project}-kms-main"
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project}-main"
  target_key_id = aws_kms_key.main.key_id
}

# --- CMK dedicada a CloudWatch Logs ----------------------------------------
resource "aws_kms_key" "logs" {
  description             = "CMK para cifrar los grupos de CloudWatch Logs"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${data.aws_region.current.name}.amazonaws.com" }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project}-kms-logs"
  }
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.project}-logs"
  target_key_id = aws_kms_key.logs.key_id
}
