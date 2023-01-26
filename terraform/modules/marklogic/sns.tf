resource "aws_sns_topic" "ml_logs" {
  name              = "marklogic-logs-${var.environment}"
  kms_master_key_id = aws_kms_key.ml_logs_encryption_key.arn
}

resource "aws_kms_key" "ml_logs_encryption_key" {
  description         = "MarkLogic logs encryption key"
  enable_key_rotation = true
}

resource "aws_kms_alias" "ml_logs_encryption_key" {
  name          = "alias/marklogic-sns-logs-${var.environment}"
  target_key_id = aws_kms_key.ml_logs_encryption_key.key_id
}
