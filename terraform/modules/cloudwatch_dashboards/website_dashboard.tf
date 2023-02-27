resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-website"
  dashboard_body = jsonencode(
    {
      "widgets" : [
        # cloudfront metrics
        {
          "width" : 24,
          "height" : 2,
          "y" : 0,
          "x" : 0,
          "type" : "alarm",
          "properties" : {
            "alarms" : var.delta_cloudfront_alarms,
            "title" : "Alarms"
          }
        },
        {
          "width" : 6,
          "height" : 6,
          "x" : 0,
          "y" : 2,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["AWS/CloudFront", "5xxErrorRate", "Region", "Global", "DistributionId", var.delta_cloudfront_distribution_id, { region : "us-east-1" }],
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
          "width" : 6,
          "height" : 6,
          "x" : 0,
          "y" : 8,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["AWS/CloudFront", "4xxErrorRate", "Region", "Global", "DistributionId", var.delta_cloudfront_distribution_id, { region : "us-east-1" }],
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
          "width" : 6,
          "height" : 6,
          "x" : 6,
          "y" : 8,
          "type" : "metric",
          "properties" : {
            "legend" : {
              "position" : "bottom"
            },
            "title" : "RequestCount: Sum",
            "region" : "eu-west-1",
            "liveData" : false,
            "start" : "-PT3H",
            "end" : "P0D",
            "view" : "timeSeries",
            "stacked" : false,
            "metrics" : [
              ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.delta_alb_arn_suffix]
            ]
          }
        },
        {
          "width" : 6,
          "height" : 6,
          "x" : 6,
          "y" : 14,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["AWS/ApplicationELB", "ActiveConnectionCount", "LoadBalancer", var.delta_alb_arn_suffix, { id : "m1", stat : "Sum" }]
            ],
            "legend" : {
              "position" : "bottom"
            },
            "title" : "ActiveConnectionCount: Sum",
            "region" : "eu-west-1",
            "liveData" : false,
            "start" : "-PT3H",
            "end" : "P0D",
            "view" : "timeSeries",
            "stacked" : false,
            "stat" : "Average",
            "period" : 300
          }
        },
        {
          "width" : 6,
          "height" : 6,
          "x" : 6,
          "y" : 2,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["AWS/ApplicationELB", "ProcessedBytes", "LoadBalancer", var.delta_alb_arn_suffix]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Sum",
            "period" : 300
          }
        },
        {
          "width" : 6,
          "height" : 6,
          "x" : 6,
          "y" : 20,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["AWS/ApplicationELB", "NewConnectionCount", "LoadBalancer", var.delta_alb_arn_suffix]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Sum",
            "period" : 300
          }
        },
        # ECS instance metrics from the Delta project. See <delta>/terraform/modules/delta_servers/app_logs.tf
        {
          "width" : 6,
          "height" : 6,
          "x" : 12,
          "y" : 2,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["${var.environment}/DeltaServers", "cpu_usage_active", { id : "m1", stat : "Minimum" }],
              ["...", { id : "m2" }],
              ["...", { id : "m3", stat : "Maximum" }]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Average",
            "period" : 300,
            "setPeriodToTimeRange" : false,
            "sparkline" : true,
            "trend" : true
          }
        },
        {
          "type" : "metric",
          "width" : 6,
          "height" : 6,
          "x" : 12,
          "y" : 8,
          "properties" : {
            "view" : "timeSeries",
            "stacked" : false,
            "metrics" : [
              ["${var.environment}/DeltaServers", "disk_used_percent", { id : "m1", stat : "Minimum" }],
              ["...", { id : "m2" }],
              ["...", { id : "m3", stat : "Maximum" }]
            ],
            "region" : "eu-west-1"
          }
        },
        {
          "type" : "metric",
          "width" : 6,
          "height" : 6,
          "x" : 12,
          "y" : 14,
          "properties" : {
            "view" : "timeSeries",
            "stacked" : false,
            "metrics" : [
              ["${var.environment}/DeltaServers", "mem_used_percent", { id : "m1", stat : "Minimum" }],
              ["...", { id : "m2" }],
              ["...", { id : "m3", stat : "Maximum" }]
            ],
            "region" : "eu-west-1"
          }
        }
      ]
    }
  )
}
