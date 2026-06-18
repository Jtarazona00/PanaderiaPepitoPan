# ---------------------------------------------------------------------------
# Lambda — función de manejo asíncrono de errores.
#
# Consume la cola SQS, procesa los eventos de error y publica una alerta en
# SNS. Las variables de entorno se cifran con la CMK general y la traza se
# envía a X-Ray.
#
# NOTA: el paquete de despliegue (lambda/error_handler.zip) se construye en el
# pipeline de CI antes de aplicar Terraform.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

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
  function_name = "${var.project}-error-handler"
  role          = aws_iam_role.lambda.arn
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  filename      = "${path.module}/lambda/error_handler.zip"
  timeout       = 30
  memory_size   = 256

  kms_key_arn = aws_kms_key.main.arn

  environment {
    variables = {
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
