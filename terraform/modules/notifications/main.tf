provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

locals {
  alarm_sns_topic_emails = ["Group-DLUHCDeltaNotifications+test@softwire.com"]
}

resource "aws_sns_topic" "alarm_sns_topic" {
  name         = "metric-alarms-${var.environment}"
  display_name = "Notifications for change in metric alarm status"
}

resource "aws_sns_topic_subscription" "alarm_sns_topic" {
  for_each = toset(local.alarm_sns_topic_emails)

  topic_arn = aws_sns_topic.alarm_sns_topic.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sns_topic" "alarm_sns_topic_global" {
  provider     = aws.us-east-1
  name         = "metric-alarms-${var.environment}"
  display_name = "Notifications for change in metric alarm status"
}

resource "aws_sns_topic_subscription" "alarm_sns_topic_global" {
  provider = aws.us-east-1

  for_each = toset(local.alarm_sns_topic_emails)

  topic_arn = aws_sns_topic.alarm_sns_topic_global.arn
  protocol  = "email"
  endpoint  = each.value
}
