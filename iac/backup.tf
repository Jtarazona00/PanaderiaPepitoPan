# ---------------------------------------------------------------------------
# AWS Backup — respaldo diario de la base de datos.
#
# Vault cifrado con la CMK general. Plan diario a las 5 AM con retención de
# 30 días, que respalda la instancia RDS primaria.
# ---------------------------------------------------------------------------

resource "aws_backup_vault" "main" {
  name        = "${var.project}-vault"
  kms_key_arn = aws_kms_key.main.arn

  tags = {
    Name = "${var.project}-vault"
  }
}

resource "aws_backup_plan" "main" {
  name = "${var.project}-plan"

  rule {
    rule_name         = "respaldo-diario"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 * * ? *)"
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = 30
    }
  }

  tags = {
    Name = "${var.project}-plan"
  }
}

data "aws_iam_policy_document" "backup_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.project}-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume.json
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_selection" "rds" {
  name         = "${var.project}-rds-seleccion"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.main.id

  resources = [
    aws_db_instance.primary.arn
  ]
}
