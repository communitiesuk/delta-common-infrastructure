resource "aws_sns_topic" "ml_logs" {
  name = "marklogic-logs-${var.environment}"

  tags = var.default_tags
}
