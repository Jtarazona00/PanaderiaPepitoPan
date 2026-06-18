# ---------------------------------------------------------------------------
# SQS — manejo asíncrono de errores.
#
# Una cola general recibe los eventos de error; los mensajes que no se procesan
# tras varios intentos pasan a la DLQ (retención 14 días). Ambas colas cifradas
# con la CMK general.
# ---------------------------------------------------------------------------

resource "aws_sqs_queue" "dlq" {
  name                              = "${var.project}-errores-dlq"
  message_retention_seconds         = 1209600 # 14 días
  kms_master_key_id                 = aws_kms_key.main.arn
  kms_data_key_reuse_period_seconds = 300

  tags = {
    Name = "${var.project}-errores-dlq"
  }
}

resource "aws_sqs_queue" "main" {
  name                              = "${var.project}-errores"
  message_retention_seconds         = 345600 # 4 días
  visibility_timeout_seconds        = 60
  receive_wait_time_seconds         = 10
  kms_master_key_id                 = aws_kms_key.main.arn
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })

  tags = {
    Name = "${var.project}-errores"
  }
}

resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.main.arn]
  })
}
