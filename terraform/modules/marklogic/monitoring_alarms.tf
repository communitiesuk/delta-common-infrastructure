locals {
  alarm_description_template = "Average instance %v utilization %v last %d minutes"
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilisation_high" {
  alarm_name          = "marklogic-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "cpu_usage_active"
  namespace           = "${var.environment}/MarkLogic"
  period              = 300
  statistic           = "Average"
  threshold           = 95 # TODO: DT-300 reduce this

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

  alarm_description         = format(local.alarm_description_template, "Disk Usage", "High", var.data_disk_usage_alarm_threshold_percent)
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

  dimensions = {
    path = "/var/opt/MarkLogic"
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_host_high" {
  alarm_name          = "marklogic-${var.environment}-lb-unhealthy-host-count-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0

  alarm_description  = "There is at least one unhealthy host"
  alarm_actions      = [var.alarms_sns_topic_arn]
  ok_actions         = [var.alarms_sns_topic_arn]
  treat_missing_data = "breaching"

  dimensions = {
    # The target groups all use the same healthcheck so it doesn't matter which one we pick
    "TargetGroup" : aws_lb_target_group.ml["8001"].arn_suffix
    "LoadBalancer" : aws_lb.ml_lb.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "healthy_host_low" {
  alarm_name          = "marklogic-${var.environment}-lb-healthy-host-count-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = 300
  statistic           = "Minimum"
  threshold           = 3

  alarm_description  = "There are less healthy hosts than expected"
  alarm_actions      = [var.alarms_sns_topic_arn]
  ok_actions         = [var.alarms_sns_topic_arn]
  treat_missing_data = "breaching"

  dimensions = {
    "TargetGroup" : aws_lb_target_group.ml["8001"].arn_suffix
    "LoadBalancer" : aws_lb.ml_lb.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "queue_length_high" {
  alarm_name          = "marklogic-${var.environment}-ebs-queue-length-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 6

  alarm_description  = "Queue length is higher than expected"
  alarm_actions      = [var.alarms_sns_topic_arn]
  ok_actions         = [var.alarms_sns_topic_arn]
  treat_missing_data = "notBreaching"

  dynamic "metric_query" {
    for_each = aws_ebs_volume.marklogic_data_volumes
    iterator = volume

    content {
      id = "volume_${replace(volume.value.availability_zone, "-", "_")}_queue_length"
      metric {
        metric_name = "VolumeQueueLength"
        namespace   = "AWS/EBS"
        period      = "300"
        stat        = "p90"
        dimensions = {
          "VolumeId" = volume.value.id
        }
      }
    }
  }

  metric_query {
    id          = "maximum_queue_length"
    expression  = "MAX(METRICS())"
    label       = "Maximum queue length for EBS volumes"
    return_data = "true"
  }
}

resource "aws_cloudwatch_metric_alarm" "swap_usage_high" {
  alarm_name          = "marklogic-${var.environment}-swap-used-percent-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "swap_used_percent"
  namespace           = "${var.environment}/MarkLogic"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1

  alarm_description  = "Swap usage percentage is higher than expected"
  alarm_actions      = [var.alarms_sns_topic_arn]
  ok_actions         = [var.alarms_sns_topic_arn]
  treat_missing_data = "notBreaching"

  dimensions = {}
}

resource "aws_cloudwatch_metric_alarm" "time_since_payments_content_backup_high" {
  alarm_name          = "marklogic-${var.environment}-time-since-payments-content-backup-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "scripted-metrics"
  namespace           = "${var.environment}/MarkLogic"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1800 //30 hours in minutes

  alarm_description  = "Longer than expected since payments-content was backed up"
  alarm_actions      = [var.alarms_sns_topic_arn]
  ok_actions         = [var.alarms_sns_topic_arn]
  treat_missing_data = "missing"
  dimensions = {
    "metric" = "payments-content-minutes-since-backup"
  }
}

resource "aws_cloudwatch_metric_alarm" "time_since_delta_content_backup_high" {
  alarm_name          = "marklogic-${var.environment}-time-since-delta-content-backup-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "scripted-metrics"
  namespace           = "${var.environment}/MarkLogic"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1800 //30 hours in minutes

  alarm_description  = "Longer than expected since delta-content was backed up"
  alarm_actions      = [var.alarms_sns_topic_arn]
  ok_actions         = [var.alarms_sns_topic_arn]
  treat_missing_data = "missing"
  dimensions = {
    "metric" = "delta-content-minutes-since-backup"
  }
}

resource "aws_cloudwatch_metric_alarm" "time_since_payments_content_incremental_backup_high" {
  alarm_name          = "marklogic-${var.environment}-time-since-payments-content-incremental-backup-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "scripted-metrics"
  namespace           = "${var.environment}/MarkLogic"
  period              = 300
  statistic           = "Maximum"
  threshold           = 900 //15 hours in minutes

  alarm_description  = "Longer than expected since payments-content was incrementally backed up"
  alarm_actions      = [var.alarms_sns_topic_arn]
  ok_actions         = [var.alarms_sns_topic_arn]
  treat_missing_data = "missing"
  dimensions = {
    "metric" = "payments-content-minutes-since-incr-backup"
  }
}

resource "aws_cloudwatch_metric_alarm" "time_since_delta_content_incremental_backup_high" {
  alarm_name          = "marklogic-${var.environment}-time-since-delta-content-incremental-backup-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "scripted-metrics"
  namespace           = "${var.environment}/MarkLogic"
  period              = 300
  statistic           = "Maximum"
  threshold           = 900 //15 hours in minutes

  alarm_description  = "Longer than expected since delta-content was incrementally backed up"
  alarm_actions      = [var.alarms_sns_topic_arn]
  ok_actions         = [var.alarms_sns_topic_arn]
  treat_missing_data = "missing"
  dimensions = {
    "metric" = "delta-content-minutes-since-incr-backup"
  }
}

resource "aws_cloudwatch_metric_alarm" "task_server_queue_size_high" {
  alarm_name          = "marklogic-${var.environment}-task-server-queue-size-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 18
  metric_name         = "scripted-metrics"
  namespace           = "${var.environment}/MarkLogic"
  period              = 300
  statistic           = "Minimum"
  threshold           = 1000

  alarm_description  = "Task server queue size is larger than expected"
  alarm_actions      = [var.alarms_sns_topic_arn]
  ok_actions         = [var.alarms_sns_topic_arn]
  treat_missing_data = "missing"
  dimensions = {
    "metric" = "task-server-total-queue-size"
  }
}
