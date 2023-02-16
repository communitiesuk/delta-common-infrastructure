locals {
  alarm_description_template = "Average instance %v utilization %v last %d minutes"
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilisation_high" {
  alarm_name          = "marklogic-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "cpu_usage_active"
  namespace           = "${var.environment}/MarkLogic"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  alarm_description = format(local.alarm_description_template, "CPU", "High", 5)
  alarm_actions     = [var.alarms_sns_topic_arn]
  ok_actions        = [var.alarms_sns_topic_arn]

  dimensions = {
    #    TODO:DT-51 How do I get the instances?
    #    "InstanceId" = aws_cloudformation_stack.marklogic
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_utilisation_high" {
  alarm_name          = "marklogic-${var.environment}-memory-used-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "mem_used_percent"
  namespace           = "${var.environment}/MarkLogic"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  alarm_description = format(local.alarm_description_template, "Memory Usage", "High", 5)
  alarm_actions     = [var.alarms_sns_topic_arn]
  ok_actions        = [var.alarms_sns_topic_arn]

  dimensions = {}
}

resource "aws_cloudwatch_metric_alarm" "disk_utilisation_high" {
  alarm_name          = "marklogic-${var.environment}-disk-used-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "disk_used_percent"
  namespace           = "${var.environment}/MarkLogic"
  period              = 300
  statistic           = "Average"
  threshold           = 90

  alarm_description = format(local.alarm_description_template, "Disk Usage", "High", 5)
  alarm_actions     = [var.alarms_sns_topic_arn]
  ok_actions        = [var.alarms_sns_topic_arn]

  dimensions = {}
}

resource "aws_cloudwatch_metric_alarm" "disk_utilisation_high_sustained" {
  alarm_name          = "marklogic-${var.environment}-disk-used-high-sustained"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "disk_used_percent"
  namespace           = "${var.environment}/MarkLogic"
  period              = 3600
  statistic           = "Average"
  threshold           = 50

  alarm_description = format(local.alarm_description_template, "Disk Usage", "High", 5)
  alarm_actions     = [var.alarms_sns_topic_arn]
  ok_actions        = [var.alarms_sns_topic_arn]

  dimensions = {}
}
