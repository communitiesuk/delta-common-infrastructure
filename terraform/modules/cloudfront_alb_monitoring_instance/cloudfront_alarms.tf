# While metrics can be created cross-regionally, alarms can't
# so we need to create these in us-east-1 as that's where the
# Global cloudfront lives
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
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

  alarm_description = <<EOF
The ${var.prefix} CloudFront distribution is returning a large number of 4xx errors to users.
This usually indicates the application itself is returning 4xx errors, but could be due to CloudFront rejecting the requests for another reason.
Look at the application/ALB metrics first, then investigate the application itself or the WAF logs in CloudWatch/CloudFront logs in S3 as appropriate.
  EOF
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

  alarm_description = <<EOF
The ${var.prefix} CloudFront distribution is returning a large number of 5xx errors to users.
This usually indicates the application itself is returning 5xx errors, but could be due to CloudFront rejecting the requests for another reason, or not being able to reach the load balancer.
Look at the application/ALB metrics first to determine whether the issue is with the application or CloudFront, then investigate the application itself or the CloudFront logs in S3 as appropriate.
  EOF
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

  alarm_description = <<EOF
The ${var.prefix} CloudFront distribution is reporting that requests to its origin (the ALB behind it) are taking longer than expected on average.
This can be a false alarm if only a small number of users are using the service, so it can be ignored outside of business hours.
  EOF
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

  alarm_description = <<EOF
The ${var.prefix} CloudFront distribution is reporting that requests to its origin (the ALB behind it) are taking longer than expected (90th percentile > ${var.cloudfront_p90_origin_latency_high_alarm_threshold_ms}ms).
This can be a false alarm if only a small number of users are using the service, so it can be ignored outside of business hours.
  EOF
  alarm_actions     = [var.alarms_sns_topic_global_arn]
  ok_actions        = [var.alarms_sns_topic_global_arn]

  dimensions = {
    "DistributionId" : var.cloudfront_distribution_id,
    "Region" : "Global"
  }
}

resource "aws_cloudwatch_metric_alarm" "ddos_attack" {
  count    = var.enable_aws_shield_alarms ? 1 : 0
  provider = aws.us-east-1

  alarm_name          = "${var.prefix}-ddos-attack"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DDoSDetected"
  namespace           = "AWS/DDoSProtection"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "Triggers when AWS Shield Advanced detects a DDoS attack. Escalate immediately."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.security_sns_topic_global_arn]
  ok_actions          = [var.security_sns_topic_global_arn]
}
