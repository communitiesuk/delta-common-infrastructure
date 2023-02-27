output "alarms" {
  value = [aws_cloudwatch_metric_alarm.client_error_rate_alarm.arn,
    aws_cloudwatch_metric_alarm.server_error_rate_alarm.arn,
  aws_cloudwatch_metric_alarm.origin_latency_high_alarm.arn]
}
