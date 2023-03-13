locals {
  green  = "#2ca02c"
  blue   = "#1f77b4"
  orange = "#ff7f0e"
  red    = "#d62728"
  # Instance metrics from the deployment. E.g. see <delta>/terraform/modules/delta_servers/app_logs.tf
  instance_metrics = var.instance_metric_namespace == null ? tolist([]) : tolist([
    {
      width : 6,
      height : 6,
      x : 18,
      y : 2,
      type : "metric",
      properties : {
        "title" : "CPU used %",
        "view" : "timeSeries",
        "stacked" : false,
        "metrics" : [
          [var.instance_metric_namespace, "cpu_usage_active", { id : "m1", stat : "Minimum" }],
          ["...", { id : "m2" }],
          ["...", { id : "m3", stat : "Maximum" }]
        ],
        "region" : "eu-west-1",
      }
    },
    {
      type : "metric",
      width : 6,
      height : 6,
      x : 18,
      y : 8,
      properties : {
        "title" : "System disk used %",
        "view" : "timeSeries",
        "stacked" : false,
        "metrics" : [
          [var.instance_metric_namespace, "disk_used_percent", { id : "m1", stat : "Minimum" }],
          ["...", { id : "m2" }],
          ["...", { id : "m3", stat : "Maximum" }]
        ],
        "region" : "eu-west-1"
      }
    },
    {
      type : "metric",
      width : 6,
      height : 6,
      x : 18,
      y : 14,
      properties : {
        "title" : "RAM used %",
        "view" : "timeSeries",
        "stacked" : false,
        "metrics" : [
          [var.instance_metric_namespace, "mem_used_percent", { id : "m1", stat : "Minimum" }],
          ["...", { id : "m2" }],
          ["...", { id : "m3", stat : "Maximum" }]
        ],
        "region" : "eu-west-1"
      }
    }
  ])
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = var.dashboard_name
  dashboard_body = jsonencode(
    {
      "widgets" : concat([
        # cloudfront metrics
        {
          width : 24,
          height : 2,
          y : 0,
          x : 0,
          type : "alarm",
          properties : {
            "alarms" : concat(var.cloudfront_alarms, [aws_cloudwatch_metric_alarm.alb_target_server_error_rate_alarm.arn, aws_cloudwatch_metric_alarm.alb_target_client_error_rate_alarm.arn]),
            "title" : "Alarms"
          }
        },
        {
          width : 6,
          height : 6,
          x : 0,
          y : 2,
          type : "metric",
          properties : {
            "title" : "CloudFront 5xx error rates",
            "metrics" : [
              ["AWS/CloudFront", "5xxErrorRate", "Region", "Global", "DistributionId", var.cloudfront_distribution_id, { region : "us-east-1" }],
              [".", "504ErrorRate", ".", ".", ".", ".", { region : "us-east-1" }],
              [".", "503ErrorRate", ".", ".", ".", ".", { region : "us-east-1" }],
              [".", "502ErrorRate", ".", ".", ".", ".", { region : "us-east-1" }]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Average",
            "period" : 300
          }
        },
        {
          width : 6,
          height : 6,
          x : 0,
          y : 8,
          type : "metric",
          properties : {
            "title" : "CloudFront 4xx error rates",
            "metrics" : [
              ["AWS/CloudFront", "4xxErrorRate", "Region", "Global", "DistributionId", var.cloudfront_distribution_id, { region : "us-east-1" }],
              [".", "404ErrorRate", ".", ".", ".", ".", { region : "us-east-1" }],
              [".", "403ErrorRate", ".", ".", ".", ".", { region : "us-east-1" }],
              [".", "401ErrorRate", ".", ".", ".", ".", { region : "us-east-1" }]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Average",
            "period" : 300
          }
        },
        # Elastic (Application) Load Balancer metrics
        {
          width : 6,
          height : 6,
          x : 6,
          y : 2,
          type : "metric",
          properties : {
            "metrics" : [
              ["AWS/ApplicationELB", "ProcessedBytes", "LoadBalancer", var.alb_arn_suffix]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Sum",
            "period" : 300
          }
        },
        {
          width : 6,
          height : 6,
          x : 6,
          y : 8,
          type : "metric",
          properties : {
            "legend" : {
              "position" : "bottom"
            },
            "title" : "ALB RequestCount",
            "region" : "eu-west-1",
            "view" : "timeSeries",
            "stacked" : false,
            "stat" : "Sum",
            "metrics" : [
              ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]
            ]
          }
        },
        {
          width : 6,
          height : 6,
          x : 6,
          y : 14,
          type : "metric",
          properties : {
            "metrics" : [
              ["AWS/ApplicationELB", "ActiveConnectionCount", "LoadBalancer", var.alb_arn_suffix, { id : "m1", stat : "Sum" }]
            ],
            "legend" : {
              "position" : "bottom"
            },
            "title" : "ALB ActiveConnectionCount",
            "region" : "eu-west-1",
            "liveData" : false,
            "view" : "timeSeries",
            "stacked" : false,
            "stat" : "Sum",
            "period" : 300
          }
        },
        {
          width : 6,
          height : 6,
          x : 6,
          y : 20,
          type : "metric",
          properties : {
            "metrics" : [
              ["AWS/ApplicationELB", "NewConnectionCount", "LoadBalancer", var.alb_arn_suffix]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Sum",
            "period" : 300
          }
        },
        {
          width : 6,
          height : 6,
          x : 12,
          y : 2,
          type : "metric",
          properties : {
            "metrics" : [
              ["AWS/ApplicationELB", "HTTPCode_ELB_4XX_Count", "LoadBalancer", var.alb_arn_suffix]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Sum",
            "period" : 300
          }
        },
        {
          width : 6,
          height : 6,
          x : 12,
          y : 8,
          type : "metric",
          properties : {
            "metrics" : [
              ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix],
              ["AWS/ApplicationELB", "HTTPCode_ELB_500_Count", "LoadBalancer", var.alb_arn_suffix],
              ["AWS/ApplicationELB", "HTTPCode_ELB_502_Count", "LoadBalancer", var.alb_arn_suffix],
              ["AWS/ApplicationELB", "HTTPCode_ELB_503_Count", "LoadBalancer", var.alb_arn_suffix],
              ["AWS/ApplicationELB", "HTTPCode_ELB_504_Count", "LoadBalancer", var.alb_arn_suffix],
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Sum",
            "period" : 300
          }
        },
        {
          width : 6,
          height : 6,
          x : 12,
          y : 14,
          type : "metric",
          properties : {
            "title" : "ALB responses from targets",
            "metrics" : [
              ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", var.alb_arn_suffix, { "color" : local.green }],
              ["AWS/ApplicationELB", "HTTPCode_Target_3XX_Count", "LoadBalancer", var.alb_arn_suffix, { "color" : local.blue }],
              ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix, { "color" : local.orange }],
              ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { "color" : local.red }],
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Sum",
            "period" : 300
          }
        },
        {
          width : 6,
          height : 6,
          x : 12,
          y : 20,
          type : "metric",
          properties : {
            "title" : "ALB error responses from targets",
            "metrics" : [
              ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix, { "color" : local.orange }],
              ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { "color" : local.red }],
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Sum",
            "period" : 300
          }
        },
      ], local.instance_metrics)
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "alb_target_server_error_rate_alarm" {
  alarm_name          = "${var.dashboard_name}-target-server-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2

  threshold          = var.alb_target_server_error_rate_alarm_threshold_percent
  treat_missing_data = "notBreaching" # Data is missing if there are no requests

  alarm_description = "High ALB target 5xx error rate"
  alarm_actions     = [var.alarms_sns_topic_arn]
  ok_actions        = [var.alarms_sns_topic_arn]

  metric_query {
    id          = "thresholded_server_error_rate"
    expression  = "IF(FILL(error_response_count, 0) > ${var.alb_target_server_error_rate_alarm_threshold_count}, (FILL(error_response_count, 0) * 100)/(FILL(ok_response_count, 1), FILL(error_response_count, 0)), 0)"
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
  alarm_name          = "${var.dashboard_name}-target-client-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2

  threshold          = var.alb_target_client_error_rate_alarm_threshold_percent
  treat_missing_data = "notBreaching" # Data is missing if there are no requests

  alarm_description = "High ALB target 4xx error rate"
  alarm_actions     = [var.alarms_sns_topic_arn]
  ok_actions        = [var.alarms_sns_topic_arn]

  metric_query {
    id          = "thresholded_client_error_rate"
    expression  = "IF(FILL(error_response_count, 0) > ${var.alb_target_client_error_rate_alarm_threshold_count}, (FILL(error_response_count, 0) * 100)/(FILL(ok_response_count, 1), FILL(error_response_count, 0)), 0)"
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
