locals {
  alarm_description_template = "Average distribution %v %v last %d minutes"
}

resource "aws_cloudwatch_metric_alarm" "bad_request_error_rate_alarm" {
  # While metrics can be created cross-regionally, alarms can't
  # so we need to create this in us-east-1 as that's where the
  # Global cloudfront lives
  provider = aws.us-east-1

  alarm_name          = "${var.prefix}bad-request-error-rate"
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

resource "aws_cloudwatch_metric_alarm" "internal_server_error_rate_alarm" {
  # While metrics can be created cross-regionally, alarms can't
  # so we need to create this in us-east-1 as that's where the
  # Global cloudfront lives
  provider = aws.us-east-1

  alarm_name          = "${var.prefix}internal-server-error-rate"
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
