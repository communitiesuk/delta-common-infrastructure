locals {
  # ECS instance metrics from the deployment. E.g. see <delta>/terraform/modules/delta_servers/app_logs.tf
  ecs_metrics = var.instance_metric_namespace == null ? tolist([]) : tolist([
    {
      width : 6,
      height : 6,
      x : 12,
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
      x : 12,
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
      x : 12,
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
            "alarms" : var.cloudfront_alarms,
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
      ], local.ecs_metrics)
    }
  )
}
