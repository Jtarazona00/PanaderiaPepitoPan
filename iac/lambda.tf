# ---------------------------------------------------------------------------
# Lambda — manejo asíncrono de errores (dos funciones, como en el diagrama).
#
#   CloudWatch --(SNS)--> Lambda Trigger --> SQS Error --> Lambda Error --> SES
#
#   - Lambda Trigger: recibe la notificación de la alarma de CloudWatch y
#     encola el evento de error en SQS.
#   - Lambda Error:   consume la cola SQS y envía el correo de alerta por SES
#     a los administradores de las 350 sedes.
#
# Ambas funciones operan FUERA de la VPC (ver diagrama): solo hablan con SQS,
# SNS y SES, nunca con RDS ni Redis.
#
# El código vive en lambda/trigger/ y lambda/error_handler/; Terraform genera
# los ZIP de despliegue automáticamente con el provider archive.
# ---------------------------------------------------------------------------

# --- Empaquetado del código de las funciones -------------------------------
data "archive_file" "trigger" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/trigger"
  output_path = "${path.module}/lambda/trigger.zip"
}

data "archive_file" "error_handler" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/error_handler"
  output_path = "${path.module}/lambda/error_handler.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ===========================================================================
# Lambda Trigger — de la alarma de CloudWatch (vía SNS) a la cola SQS
# ===========================================================================

resource "aws_iam_role" "lambda_trigger" {
  name               = "${var.project}-lambda-trigger"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_trigger_basic" {
  role       = aws_iam_role.lambda_trigger.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_trigger_perms" {
  statement {
    sid       = "EncolarErrorEnSqs"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.main.arn]
  }

  statement {
    sid       = "UsarKms"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
    resources = [aws_kms_key.main.arn]
  }
}

resource "aws_iam_role_policy" "lambda_trigger_perms" {
  name   = "${var.project}-lambda-trigger-perms"
  role   = aws_iam_role.lambda_trigger.id
  policy = data.aws_iam_policy_document.lambda_trigger_perms.json
}

resource "aws_cloudwatch_log_group" "lambda_trigger" {
  name              = "/aws/lambda/${var.project}-trigger"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}

resource "aws_lambda_function" "trigger" {
  # Opera FUERA de la VPC por diseno: solo recibe la notificacion de la alarma
  # y encola el evento en SQS; no accede a RDS ni a Redis.
  #checkov:skip=CKV_AWS_117:Lambda fuera de la VPC por diseno; no accede a recursos privados.
  function_name    = "${var.project}-trigger"
  role             = aws_iam_role.lambda_trigger.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  filename         = data.archive_file.trigger.output_path
  source_code_hash = data.archive_file.trigger.output_base64sha256
  timeout          = 30
  memory_size      = 256

  kms_key_arn = aws_kms_key.main.arn

  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.main.url
      ENVIRONMENT   = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_cloudwatch_log_group.lambda_trigger]
}

# Las alarmas de CloudWatch notifican al topic SNS y este invoca a la Lambda
# Trigger (CloudWatch no puede invocar una Lambda directamente).
resource "aws_sns_topic_subscription" "trigger" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.trigger.arn
}

resource "aws_lambda_permission" "trigger_from_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

# ===========================================================================
# Lambda Error — de la cola SQS al correo de alerta por SES
# ===========================================================================

resource "aws_iam_role" "lambda" {
  name               = "${var.project}-lambda-error"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_perms" {
  statement {
    sid    = "ConsumirSqs"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [aws_sqs_queue.main.arn]
  }

  statement {
    sid    = "EnviarCorreoConSes"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "PublicarSns"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
  }

  statement {
    sid       = "UsarKms"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.main.arn]
  }
}

resource "aws_iam_role_policy" "lambda_perms" {
  name   = "${var.project}-lambda-perms"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_perms.json
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project}-error-handler"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}

resource "aws_lambda_function" "error_handler" {
  # La funcion opera FUERA de la VPC por diseno de arquitectura: solo consume
  # mensajes de SQS y envia alertas por correo, no accede a RDS ni a Redis.
  # Mantenerla fuera evita ENIs y arranques en frio innecesarios.
  #checkov:skip=CKV_AWS_117:Lambda fuera de la VPC por diseno; no accede a recursos privados.
  function_name    = "${var.project}-error-handler"
  role             = aws_iam_role.lambda.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  filename         = data.archive_file.error_handler.output_path
  source_code_hash = data.archive_file.error_handler.output_base64sha256
  timeout          = 30
  memory_size      = 256

  kms_key_arn = aws_kms_key.main.arn

  environment {
    variables = {
      SES_SENDER    = var.ses_sender_email
      ADMIN_EMAIL   = var.admin_email
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
      ENVIRONMENT   = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn = aws_sqs_queue.main.arn
  function_name    = aws_lambda_function.error_handler.arn
  batch_size       = 10
  enabled          = true
}
