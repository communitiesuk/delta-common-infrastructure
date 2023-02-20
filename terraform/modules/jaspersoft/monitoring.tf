locals {
  alarm_description_template = "Average instance %v utilization %v last %d minutes"
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilisation_high" {
  alarm_name          = "jaspersoft-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "cpu_usage_active"
  namespace           = "${var.environment}/Jaspersoft"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  alarm_description = format(local.alarm_description_template, "CPU", "High", 5)
  alarm_actions     = [var.alarms_sns_topic_arn]
  ok_actions        = [var.alarms_sns_topic_arn]

  dimensions = {}
}

resource "aws_cloudwatch_metric_alarm" "memory_utilisation_high" {
  alarm_name          = "jaspersoft-${var.environment}-memory-used-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "mem_used_percent"
  namespace           = "${var.environment}/Jaspersoft"
  period              = 300
  statistic           = "Maximum"
  threshold           = 80

  alarm_description = format(local.alarm_description_template, "Memory Usage", "High", 5)
  alarm_actions     = [var.alarms_sns_topic_arn]
  ok_actions        = [var.alarms_sns_topic_arn]

  dimensions = {}
}

resource "aws_cloudwatch_metric_alarm" "disk_utilisation_high" {
  alarm_name          = "jaspersoft-${var.environment}-disk-used-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "disk_used_percent"
  namespace           = "${var.environment}/Jaspersoft"
  period              = 300
  statistic           = "Maximum"
  threshold           = 80

  alarm_description         = format(local.alarm_description_template, "Disk Usage", "High", 5)
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

  dimensions = {}
}
