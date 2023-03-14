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
  dashboard_name = "${var.prefix}-cloudfront-alb"
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
            "alarms" : [
              aws_cloudwatch_metric_alarm.alb_target_server_error_rate_alarm.arn,
              aws_cloudwatch_metric_alarm.alb_target_client_error_rate_alarm.arn,
              aws_cloudwatch_metric_alarm.client_error_rate_alarm.arn,
              aws_cloudwatch_metric_alarm.server_error_rate_alarm.arn,
              aws_cloudwatch_metric_alarm.origin_latency_high_alarm.arn,
            ],
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
              [
                "AWS/CloudFront", "5xxErrorRate", "Region", "Global", "DistributionId", var.cloudfront_distribution_id,
                { region : "us-east-1" }
              ],
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
              [
                "AWS/CloudFront", "4xxErrorRate", "Region", "Global", "DistributionId", var.cloudfront_distribution_id,
                { region : "us-east-1" }
              ],
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
            "title" : "ALB ProcessedBytes",
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
              [
                "AWS/ApplicationELB", "ActiveConnectionCount", "LoadBalancer", var.alb_arn_suffix,
                { id : "m1", stat : "Sum" }
              ]
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
            "title" : "ALB NewConnectionCount",
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
            "title" : "ALB-generated 4xx count",
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
            "title" : "ALB-generated 5xx count",
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
              [
                "AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", var.alb_arn_suffix,
                { color : local.green }
              ],
              [
                "AWS/ApplicationELB", "HTTPCode_Target_3XX_Count", "LoadBalancer", var.alb_arn_suffix,
                { color : local.blue }
              ],
              [
                "AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix,
                { color : local.orange }
              ],
              [
                "AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix,
                { color : local.red }
              ],
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
              [
                "AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix,
                { color : local.orange }
              ],
              [
                "AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix,
                { color : local.red }
              ],
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
