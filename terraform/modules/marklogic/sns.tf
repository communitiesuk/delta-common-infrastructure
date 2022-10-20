resource "aws_sns_topic" "ml_logs" {
  name              = "marklogic-logs-${var.environment}"
  kms_master_key_id = aws_kms_key.ml_logs_encryption_key.arn
}

resource "aws_kms_key" "ml_logs_encryption_key" {
  description         = "MarkLogic logs encryption key"
  enable_key_rotation = true
}
