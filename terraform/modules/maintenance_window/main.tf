variable "environment" {
  type = string
}

variable "prefix" {
  type = string
}

variable "schedule" {
  type        = string
  description = "e.g. cron(00 06 ? * MON *)"
}

variable "enabled" {
  type    = bool
  default = true
}

variable "subscribed_emails" {
  type = list(string)
}

output "window_id" {
  value = aws_ssm_maintenance_window.main.id
}

output "service_role_arn" {
  value = aws_iam_role.main.arn
}

output "errors_sns_topic_arn" {
  value = aws_sns_topic.main.arn
}

resource "aws_ssm_maintenance_window" "main" {
  name              = "${var.prefix}-${var.environment}"
  enabled           = var.enabled
  schedule          = var.schedule
  schedule_timezone = "Etc/UTC"
  duration          = 2
  cutoff            = 1
}

# SNS topic for errors with the maintenance window job. Non-sensitive.
# tfsec:ignore:aws-sns-enable-topic-encryption
resource "aws_sns_topic" "main" {
  name = "${var.prefix}-ssm-errors-${var.environment}"
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.subscribed_emails)

  topic_arn = aws_sns_topic.main.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_iam_role" "main" {
  name = "${var.prefix}-sns-publish-${var.environment}"
  # Allow infra-support to iam:PassRole
  path = "/${var.environment}-infra-passable/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "main" {
  role       = aws_iam_role.main.name
  policy_arn = aws_iam_policy.main.arn
}

resource "aws_iam_policy" "main" {
  name        = "${var.prefix}-sns-publish-${var.environment}"
  description = "Used by SSM to push notifications when Maintenance window jobs fail"

  policy = data.aws_iam_policy_document.main.json
}

data "aws_iam_policy_document" "main" {
  statement {
    actions = ["sns:Publish"]
    effect  = "Allow"
    resources = [
      aws_sns_topic.main.arn
    ]
  }
}
