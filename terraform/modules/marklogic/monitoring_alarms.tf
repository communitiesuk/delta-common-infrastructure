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

  alarm_description         = <<EOF
${format(local.alarm_description_template, "CPU", "High", 10)}
This indicates MarkLogic is busy and will normally resolve on its own.
If it persists consider clearing the task queue.
  EOF
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

  alarm_description         = <<EOF
${format(local.alarm_description_template, "Memory Usage", "High", 10)}
Monitor and then restart the cluster in an outage window.
MarkLogic will crash and failover if it runs out of memory, which can take the whole cluster down.
  EOF
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

  alarm_description         = <<EOF
${format(local.alarm_description_template, "Memory Usage", "High (sustained)", 25)}
The cluster may need to be restarted in an outage window.
MarkLogic will crash and failover if it runs out of memory, which can take the whole cluster down.
  EOF
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

  alarm_description = <<EOF
${format(local.alarm_description_template, "Disk Usage", "High", 10)}
The system disk on one of the MarkLogic servers is nearly full. This disk should contain the OS only, not any MarkLogic data.
Connect using Systems Manager to investigate.
  EOF

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

  alarm_description = <<EOF
${format(local.alarm_description_template, "Disk Usage", "Very High", 10)}
The disk containing MarkLogic database data on one of the MarkLogic servers is nearly full.
Investigate what's causing the database to grow.
Note that if you resize the EBS volume in AWS you will need to manually remount it on each server.
  EOF

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

  alarm_description = <<EOF
${format(local.alarm_description_template, "Disk Usage", "High", var.data_disk_usage_alarm_threshold_percent)}
The disk containing MarkLogic database data on one of the MarkLogic servers is starting to fill up.
MarkLogic needs to have enough space to store two copies of any database it's restoring to, so high disk space utilisation will prevent restoring backups long before it is completely full.
  EOF

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

  alarm_description  = <<EOF
At least one of the MarkLogic servers is being reported as unhealthy by a load balancer.
This is likely to significantly degrade Delta and should be escalated during business hours.
Investigate in the MarkLogic admin console, or by connecting to a server using Systems Manager.
The autoscaling groups will not replace servers that are unhealthy on the load balancer, only if EC2 reports them as unhealthy/offline.
  EOF
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

  alarm_description  = <<EOT
  There are fewer healthy MarkLogic hosts than expected.
  This is expected during weekly patching, but outside of that requires attention as MarkLogic often struggles to recover from node failure without manual intervention.
  Investigate in the MarkLogic admin console, or by connecting to a server using Systems Manager.
  EOT
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
  threshold           = 10

  alarm_description  = <<EOT
  EBS Queue length is higher than expected for at least one node in the MarkLogic cluster.
  This means disk throughput is struggling to keep up.
  This is common when overnight jobs are running, and during backups/restores.
  It usually resolves itself, but if not check that the cluster is healthy and clear the task queue if necessary.
  EOT
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

  alarm_description  = <<EOT
  Swap usage percentage is higher than expected.
  This could indicate MarkLogic is low on memory and may need to be restarted immediately.
  EOT
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

  alarm_description         = "Longer than expected since payments-content was backed up"
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

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

  alarm_description         = "Longer than expected since delta-content was backed up"
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

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

  alarm_description         = "Longer than expected since payments-content was incrementally backed up"
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

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
  threshold           = 900 // 15 hours in minutes

  alarm_description         = "Longer than expected since delta-content was incrementally backed up"
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

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

  alarm_description         = <<EOF
Task server queue size is larger than expected.
Consider clearing the task queue.
  EOF
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

  treat_missing_data = "missing"
  dimensions = {
    "metric" = "task-server-total-queue-size"
  }
}
