locals {
  alarm_description_template = "Average distribution %v %v last %d minutes"
}

resource "aws_cloudwatch_metric_alarm" "client_error_rate_alarm" {
  # While metrics can be created cross-regionally, alarms can't
  # so we need to create this in us-east-1 as that's where the
  # Global cloudfront lives
  provider = aws.us-east-1

  alarm_name          = "${var.prefix}client-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1

  metric_name = "4xxErrorRate"
  namespace   = "AWS/CloudFront"
  period      = 300
  statistic   = "Average"
  threshold   = 1

  alarm_description = format(local.alarm_description_template, "Error Rate", "High", 5)
  alarm_actions     = [var.alarms_sns_topic_global_arn]
  ok_actions        = [var.alarms_sns_topic_global_arn]

  dimensions = {
    "DistributionId" : aws_cloudfront_distribution.main.id,
    "Region" : "Global"
  }
}

resource "aws_cloudwatch_metric_alarm" "server_error_rate_alarm" {
  # While metrics can be created cross-regionally, alarms can't
  # so we need to create this in us-east-1 as that's where the
  # Global cloudfront lives
  provider = aws.us-east-1

  alarm_name          = "${var.prefix}server-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1

  metric_name = "5xxErrorRate"
  namespace   = "AWS/CloudFront"
  period      = 300
  statistic   = "Average"
  threshold   = 1

  alarm_description = format(local.alarm_description_template, "Error Rate", "High", 5)
  alarm_actions     = [var.alarms_sns_topic_global_arn]
  ok_actions        = [var.alarms_sns_topic_global_arn]

  dimensions = {
    "DistributionId" : aws_cloudfront_distribution.main.id,
    "Region" : "Global"
  }
}

# We need to enable enhanced monitoring to get OriginLatency & CacheHitRate (+ other metrics)
resource "aws_cloudfront_monitoring_subscription" "main" {
  distribution_id = aws_cloudfront_distribution.main.id
  monitoring_subscription {
    realtime_metrics_subscription_config {
      realtime_metrics_subscription_status = "Enabled"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "origin_latency_high_alarm" {
  # While metrics can be created cross-regionally, alarms can't
  # so we need to create this in us-east-1 as that's where the
  # Global cloudfront lives
  provider = aws.us-east-1

  alarm_name          = "${var.prefix}origin-latency-high-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1

  metric_name = "OriginLatency"
  namespace   = "AWS/CloudFront"
  period      = 300
  statistic   = "Average"
  threshold   = 10000

  alarm_description = format(local.alarm_description_template, "Origin Latency", "High", 5)
  alarm_actions     = [var.alarms_sns_topic_global_arn]
  ok_actions        = [var.alarms_sns_topic_global_arn]

  dimensions = {
    "DistributionId" : aws_cloudfront_distribution.main.id,
    "Region" : "Global"
  }
}
