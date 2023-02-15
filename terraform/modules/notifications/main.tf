resource "aws_sns_topic" "alarm_sns_topic" {
  name         = "metric-alarms-${var.environment}"
  display_name = "Notifications for change in metric alarm status"
}

locals {
  alarm_sns_topic_emails = ["Group-DLUHCDeltaNotifications@softwire.com"]
}

resource "aws_sns_topic_subscription" "alarm_sns_topic" {
  for_each = toset(local.alarm_sns_topic_emails)

  topic_arn = aws_sns_topic.alarm_sns_topic.arn
  protocol  = "email"
  endpoint  = each.value
}
