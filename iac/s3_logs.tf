# ---------------------------------------------------------------------------
# Bucket S3 para los logs de acceso del ALB y de CloudFront.
#
# ---------------------------------------------------------------------------

resource "random_id" "logs_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "logs" {
  bucket = "${var.project}-access-logs-${random_id.logs_suffix.hex}"

  tags = {
    Name    = "${var.project}-access-logs"
    Purpose = "alb-cloudfront-access-logs"
  }
}

# --- Fix CKV2_AWS_6: bloqueo de acceso publico ----------------------------
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Fix CKV_AWS_21: versionado del bucket --------------------------------
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}