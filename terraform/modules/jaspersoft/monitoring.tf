resource "aws_cloudwatch_metric_alarm" "cpu_utilisation_high" {
  alarm_name          = "jaspersoft-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "cpu_usage_active"
  namespace           = "${var.environment}/Jaspersoft"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  alarm_description         = <<EOF
High CPU usage on JasperReports server.
Non-critical, only affects Delta reports.
Connect to the instance using Systems Manager Session Manager to investigate or reboot.
  EOF
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

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

  alarm_description         = <<EOF
High memory usage on JasperReports server.
Non-critical, only affects Delta reports.
Connect to the instance using Systems Manager Session Manager to investigate or reboot.
  EOF
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

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

  alarm_description         = <<EOF
High disk use on JasperReports server.
Non-critical, only affects Delta reports.
Connect to the instance using Systems Manager Session Manager to investigate.
  EOF
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

  dimensions = {}
}

resource "aws_cloudwatch_metric_alarm" "limited_free_storage_space" {
  alarm_name          = "jaspersoft-rds-${var.environment}-limited-free-storage-space"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Minimum"
  threshold           = 3000000000 // 3 GB. At time of writing 7/10GB free.

  alarm_description         = <<EOF
Low storage space remaining on JasperReports RDS instance.
Non-critical, only affects Delta reports.
  EOF
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

  dimensions = { "DBInstanceIdentifier" = aws_db_instance.jaspersoft.identifier }
}

# There's only one Jaspersoft instance, so no need to check unhealthy too
resource "aws_cloudwatch_metric_alarm" "healthy_host_low" {
  alarm_name          = "jaspersoft-${var.environment}-healthy-host-count-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Minimum"
  threshold           = 1

  alarm_description  = <<EOF
The JasperReports server is unhealthy.
Non-critical, only affects Delta reports.
Connect to the instance using Systems Manager Session Manager to investigate or reboot.
  EOF
  alarm_actions      = [var.alarms_sns_topic_arn]
  ok_actions         = [var.alarms_sns_topic_arn]
  treat_missing_data = "breaching"

  dimensions = {
    "TargetGroup" : aws_lb_target_group.main.arn_suffix
    "LoadBalancer" : var.public_alb.arn_suffix
  }
}
