# While metrics can be created cross-regionally, alarms can't
# so we need to create these in us-east-1 as that's where the
# Global cloudfront lives
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

locals {
  alarm_description_template = "Average distribution %v %v last %d minutes"
}

# We need to enable enhanced monitoring to get 4xx, 5xx, OriginLatency & CacheHitRate (+ other metrics)
resource "aws_cloudfront_monitoring_subscription" "main" {
  distribution_id = var.cloudfront_distribution_id
  monitoring_subscription {
    realtime_metrics_subscription_config {
      realtime_metrics_subscription_status = "Enabled"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "client_error_rate_alarm" {
  # While metrics can be created cross-regionally, alarms can't
  # so we need to create this in us-east-1 as that's where the
  # Global cloudfront lives
  provider = aws.us-east-1

  alarm_name          = "${var.prefix}-client-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 4 # CloudFront error rate includes geo-blocked requests, so this can be noisy

  threshold          = var.cloudfront_client_error_rate_alarm_threshold_percent
  treat_missing_data = "notBreaching" # Data is missing if there are no requests

  alarm_description = format(local.alarm_description_template, "Error Rate", "High", var.cloudfront_metric_period_seconds * 2 / 60)
  alarm_actions     = [var.alarms_sns_topic_global_arn]
  ok_actions        = [var.alarms_sns_topic_global_arn]

  metric_query {
    id          = "thresholded_client_error_rate"
    expression  = "IF(total_requests > 50, actual_client_error_rate, -1)"
    label       = "Thresholded 4xx CloudFront error rate"
    return_data = "true"
  }

  metric_query {
    id = "actual_client_error_rate"
    metric {
      metric_name = "4xxErrorRate"
      namespace   = "AWS/CloudFront"
      period      = "300"
      stat        = "Average"
      dimensions = {
        "DistributionId" : var.cloudfront_distribution_id,
        "Region" : "Global"
      }
    }
  }

  metric_query {
    id = "total_requests"
    metric {
      metric_name = "Requests"
      namespace   = "AWS/CloudFront"
      period      = "300"
      stat        = "Sum"
      dimensions = {
        "DistributionId" : var.cloudfront_distribution_id,
        "Region" : "Global"
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "server_error_rate_alarm" {
  provider = aws.us-east-1

  alarm_name          = "${var.prefix}-server-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2

  threshold          = var.cloudfront_server_error_rate_alarm_threshold_percent
  treat_missing_data = "notBreaching" # Data is missing if there are no requests

  alarm_description = format(local.alarm_description_template, "Error Rate", "High", var.cloudfront_metric_period_seconds * 2 / 60)
  alarm_actions     = [var.alarms_sns_topic_global_arn]
  ok_actions        = [var.alarms_sns_topic_global_arn]

  metric_query {
    id          = "thresholded_server_error_rate"
    expression  = "IF(total_requests > 50, actual_server_error_rate, -1)"
    label       = "Thresholded 5xx CloudFront error rate"
    return_data = "true"
  }

  metric_query {
    id = "actual_server_error_rate"
    metric {
      metric_name = "5xxErrorRate"
      namespace   = "AWS/CloudFront"
      period      = "300"
      stat        = "Average"
      dimensions = {
        "DistributionId" : var.cloudfront_distribution_id,
        "Region" : "Global"
      }
    }
  }

  metric_query {
    id = "total_requests"
    metric {
      metric_name = "Requests"
      namespace   = "AWS/CloudFront"
      period      = "300"
      stat        = "Sum"
      dimensions = {
        "DistributionId" : var.cloudfront_distribution_id,
        "Region" : "Global"
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "origin_latency_high_alarm" {
  provider = aws.us-east-1

  alarm_name          = "${var.prefix}-origin-latency-average-high-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2

  metric_name        = "OriginLatency"
  namespace          = "AWS/CloudFront"
  period             = var.cloudfront_metric_period_seconds
  statistic          = "Average"
  threshold          = var.cloudfront_average_origin_latency_high_alarm_threshold_ms
  treat_missing_data = "notBreaching" # Data is missing if there are no requests

  alarm_description = format(local.alarm_description_template, "Origin Latency", "High", var.cloudfront_metric_period_seconds * 2 / 60)
  alarm_actions     = [var.alarms_sns_topic_global_arn]
  ok_actions        = [var.alarms_sns_topic_global_arn]

  dimensions = {
    "DistributionId" : var.cloudfront_distribution_id,
    "Region" : "Global"
  }
}

resource "aws_cloudwatch_metric_alarm" "origin_latency_p90_high_alarm" {
  provider = aws.us-east-1
  count    = var.cloudfront_p90_origin_latency_high_alarm_threshold_ms == null ? 0 : 1

  alarm_name          = "${var.prefix}-origin-latency-p90-high-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2

  metric_name        = "OriginLatency"
  namespace          = "AWS/CloudFront"
  period             = var.cloudfront_metric_period_seconds
  extended_statistic = "p90"
  threshold          = var.cloudfront_p90_origin_latency_high_alarm_threshold_ms
  treat_missing_data = "notBreaching" # Data is missing if there are no requests

  alarm_description = format(local.alarm_description_template, "Origin Latency P90", "High", var.cloudfront_metric_period_seconds * 2 / 60)
  alarm_actions     = [var.alarms_sns_topic_global_arn]
  ok_actions        = [var.alarms_sns_topic_global_arn]

  dimensions = {
    "DistributionId" : var.cloudfront_distribution_id,
    "Region" : "Global"
  }
}

resource "aws_cloudwatch_metric_alarm" "ddos_attack" {
  provider = aws.us-east-1

  alarm_name          = "${var.prefix}-ddos-attack"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DDoSDetected"
  namespace           = "AWS/DDoSProtection"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "Triggers when AWS Shield Advanced detects a DDoS attack"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.security_sns_topic_global_arn]
  ok_actions          = [var.security_sns_topic_global_arn]
}
