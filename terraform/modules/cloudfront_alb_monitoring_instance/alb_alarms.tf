resource "aws_cloudwatch_metric_alarm" "alb_target_server_error_rate_alarm" {
  alarm_name          = "${var.prefix}-target-server-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2

  threshold = var.alb_target_server_error_rate_alarm_threshold_percent

  alarm_description         = "High ALB target 5xx error rate"
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

  metric_query {
    id          = "thresholded_server_error_rate"
    expression  = "IF(FILL(error_response_count, 0) > ${var.alb_target_server_error_rate_alarm_threshold_count}, (FILL(error_response_count, 0) * 100)/(FILL(ok_response_count, 1) + FILL(error_response_count, 0)), 0)"
    label       = "Thresholded 5xx ALB target error rate %"
    return_data = "true"
  }

  metric_query {
    id = "error_response_count"
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = "300"
      stat        = "Sum"
      dimensions  = { "LoadBalancer" : var.alb_arn_suffix }
    }
  }

  metric_query {
    id = "ok_response_count"
    metric {
      metric_name = "HTTPCode_Target_2XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = "300"
      stat        = "Sum"
      dimensions  = { "LoadBalancer" : var.alb_arn_suffix }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_target_client_error_rate_alarm" {
  alarm_name          = "${var.prefix}-target-client-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2

  threshold = var.alb_target_client_error_rate_alarm_threshold_percent

  alarm_description         = "High ALB target 4xx error rate"
  alarm_actions             = [var.alarms_sns_topic_arn]
  ok_actions                = [var.alarms_sns_topic_arn]
  insufficient_data_actions = [var.alarms_sns_topic_arn]

  metric_query {
    id          = "thresholded_client_error_rate"
    expression  = "IF(FILL(error_response_count, 0) > ${var.alb_target_client_error_rate_alarm_threshold_count}, (FILL(error_response_count, 0) * 100)/(FILL(ok_response_count, 1) + FILL(error_response_count, 0)), 0)"
    label       = "Thresholded 4xx ALB target error rate %"
    return_data = "true"
  }

  metric_query {
    id = "error_response_count"
    metric {
      metric_name = "HTTPCode_Target_4XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = "300"
      stat        = "Sum"
      dimensions  = { "LoadBalancer" : var.alb_arn_suffix }
    }
  }

  metric_query {
    id = "ok_response_count"
    metric {
      metric_name = "HTTPCode_Target_2XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = "300"
      stat        = "Sum"
      dimensions  = { "LoadBalancer" : var.alb_arn_suffix }
    }
  }
}
