locals {
  alarm_description_template = "Average instance %v utilization %v last %d minutes"
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilisation_high" {
  alarm_name          = "marklogic-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "cpu_usage_active"
  namespace           = "${var.environment}/MarkLogic"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  alarm_description         = format(local.alarm_description_template, "CPU", "High", 10)
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

  dimensions = {
    #    TODO:DT-257 Consider per-instance alarms.
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_utilisation_high" {
  alarm_name          = "marklogic-${var.environment}-memory-used-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "mem_used_percent"
  namespace           = "${var.environment}/MarkLogic"
  period              = 300
  statistic           = "Maximum"
  threshold           = 90

  alarm_description         = format(local.alarm_description_template, "Memory Usage", "High", 10)
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

  dimensions = {}
}

resource "aws_cloudwatch_metric_alarm" "memory_utilisation_high_sustained" {
  alarm_name          = "marklogic-${var.environment}-memory-used-high-sustained"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "mem_used_percent"
  namespace           = "${var.environment}/MarkLogic"
  period              = 300
  statistic           = "Maximum"
  threshold           = 85

  alarm_description         = format(local.alarm_description_template, "Memory Usage", "High (sustained)", 25)
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

  dimensions = {}
}

resource "aws_cloudwatch_metric_alarm" "system_disk_utilisation_high" {
  alarm_name          = "marklogic-${var.environment}-system-disk-used-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "disk_used_percent"
  namespace           = "${var.environment}/MarkLogic"
  period              = 300
  statistic           = "Maximum"
  threshold           = 90

  alarm_description         = format(local.alarm_description_template, "Disk Usage", "High", 10)
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

  dimensions = {
    path = "/"
  }
}

resource "aws_cloudwatch_metric_alarm" "data_disk_utilisation_high" {
  alarm_name          = "marklogic-${var.environment}-data-disk-used-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "disk_used_percent"
  namespace           = "${var.environment}/MarkLogic"
  period              = 300
  statistic           = "Maximum"
  threshold           = 90

  alarm_description         = format(local.alarm_description_template, "Disk Usage", "High", 10)
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

  dimensions = {
    path = "/var/opt/MarkLogic"
  }
}

resource "aws_cloudwatch_metric_alarm" "data_disk_utilisation_high_sustained" {
  alarm_name          = "marklogic-${var.environment}-data-disk-used-high-sustained"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 4
  metric_name         = "disk_used_percent"
  namespace           = "${var.environment}/MarkLogic"
  period              = 900
  statistic           = "Maximum"
  threshold           = var.data_disk_usage_alarm_threshold_percent

  alarm_description         = format(local.alarm_description_template, "Disk Usage", "High", 60)
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

  dimensions = {
    path = "/var/opt/MarkLogic"
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_host_high" {
  alarm_name          = "marklogic-load-balancer-unhealthy-host-count-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = 300
  statistic           = "Average"
  threshold           = 0

  alarm_description = "There is at least one unhealthy host"
  alarm_actions     = [var.alarms_sns_topic_arn]
  ok_actions        = [var.alarms_sns_topic_arn]

  dimensions = {
    "TargetGroup" : aws_lb_target_group.ml["8001"].arn_suffix
    "LoadBalancer" : aws_lb.ml_lb.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "healthy_host_low" {
  alarm_name          = "marklogic-load-balancer-healthy-host-count-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = 300
  statistic           = "Average"
  threshold           = var.desired_count

  alarm_description = "There are less healthy hosts than expected"
  alarm_actions     = [var.alarms_sns_topic_arn]
  ok_actions        = [var.alarms_sns_topic_arn]

  dimensions = {
    "TargetGroup" : aws_lb_target_group.ml["8001"].arn_suffix
    "LoadBalancer" : aws_lb.ml_lb.arn_suffix
  }
}
