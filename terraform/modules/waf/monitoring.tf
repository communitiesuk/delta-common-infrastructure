resource "aws_cloudwatch_dashboard" "waf_dashboard" {
  dashboard_name = "${var.prefix}cloudfront-waf"

  dashboard_body = jsonencode(
    {
      widgets = concat([
        {
          type = "metric",
          properties = {
            "stat" : "Sum",
            "view" : "timeSeries",
            "stacked" : false,
            "metrics" : [
              ["AWS/WAFV2", "AllowedRequests", "Rule", "ALL", "WebACL", aws_wafv2_web_acl.waf_acl.name, { "color" : "#1f77b4" }],
              ["AWS/WAFV2", "CountedRequests", "Rule", "ALL", "WebACL", aws_wafv2_web_acl.waf_acl.name, { "color" : "#ff7f0e" }],
              ["AWS/WAFV2", "BlockedRequests", "Rule", "ALL", "WebACL", aws_wafv2_web_acl.waf_acl.name, { "color" : "#d62728" }],
            ],
            "region" : "us-east-1",
            "title" : "All requests",
            "yAxis" : {
              "left" : {
                "min" : 0,
                "label" : "Request count"
              }
            },
            "period" : 300
          }
          height = 8
          width  = 12
          x      = 0
          y      = 0
        },
        {
          type = "metric",
          properties = {
            "stat" : "Sum",
            "view" : "timeSeries",
            "stacked" : false,
            "metrics" : concat([
              ["AWS/WAFV2", "BlockedRequests", "Rule", local.metric_names.rate_limit, "WebACL", aws_wafv2_web_acl.waf_acl.name],
              ["AWS/WAFV2", "BlockedRequests", "Rule", local.metric_names.common, "WebACL", aws_wafv2_web_acl.waf_acl.name],
              ["AWS/WAFV2", "CountedRequests", "Rule", local.metric_names.common, "WebACL", aws_wafv2_web_acl.waf_acl.name],
              ["AWS/WAFV2", "BlockedRequests", "Rule", local.metric_names.bad_inputs, "WebACL", aws_wafv2_web_acl.waf_acl.name],
              ["AWS/WAFV2", "CountedRequests", "Rule", local.metric_names.bad_inputs, "WebACL", aws_wafv2_web_acl.waf_acl.name],
              ["AWS/WAFV2", "BlockedRequests", "Rule", local.metric_names.ip_reputation, "WebACL", aws_wafv2_web_acl.waf_acl.name],
              ["AWS/WAFV2", "CountedRequests", "Rule", local.metric_names.ip_reputation, "WebACL", aws_wafv2_web_acl.waf_acl.name],
              ],
              !var.login_ip_rate_limit_enabled ? [] : [
                ["AWS/WAFV2", "BlockedRequests", "Rule", local.metric_names.login_ip_rate_limit, "WebACL", aws_wafv2_web_acl.waf_acl.name],
                ["AWS/WAFV2", "CountedRequests", "Rule", local.metric_names.login_ip_rate_limit, "WebACL", aws_wafv2_web_acl.waf_acl.name],
            ]),
            "region" : "us-east-1",
            "title" : "Blocked and counted requests by rule group",
            "yAxis" : {
              "left" : {
                "min" : 0,
                "label" : "Request count"
              }
            },
            "period" : 300
          }
          height = 8
          width  = 12
          x      = 0
          y      = 8
        },
        {
          type = "metric",
          properties = {
            "title" : "Blocked requests alarm",
            "annotations" : {
              "alarms" : [aws_cloudwatch_metric_alarm.blocked_requests.arn]
            },
            "liveData" : false,
            "start" : "-PT3H",
            "end" : "PT0H",
            "region" : "us-east-1",
            "view" : "timeSeries",
            "stacked" : false
          }
          height = 8
          width  = 8
          x      = 12
          y      = 0
        },
        ],
        !var.login_ip_rate_limit_enabled ? [] : [
          {
            type = "metric",
            properties = {
              "title" : "Blocked login requests alarm",
              "annotations" : {
                "alarms" : [aws_cloudwatch_metric_alarm.blocked_login_requests[0].arn]
              },
              "liveData" : false,
              "start" : "-PT3H",
              "end" : "PT0H",
              "region" : "us-east-1",
              "view" : "timeSeries",
              "stacked" : false
            }
            height = 8
            width  = 8
            x      = 12
            y      = 0
          }
      ])
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "blocked_requests" {
  provider = aws.us-east-1

  alarm_name          = "${var.prefix}cloudfront-waf-blocked-requests"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1000"
  alarm_description   = "WAF ${aws_wafv2_web_acl.waf_acl.name} blocking large number of requests"
  treat_missing_data  = "notBreaching"
  dimensions = {
    Rule   = "ALL"
    WebACL = aws_wafv2_web_acl.waf_acl.name
  }

  alarm_actions = [var.security_sns_topic_global_arn]
  ok_actions    = [var.security_sns_topic_global_arn]
}

resource "aws_cloudwatch_metric_alarm" "blocked_login_requests" {
  provider = aws.us-east-1
  count    = var.login_ip_rate_limit_enabled ? 1 : 0

  alarm_name          = "${var.prefix}cloudfront-waf-blocked-login-requests"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "WAF ${aws_wafv2_web_acl.waf_acl.name} blocking large number of login requests"
  treat_missing_data  = "notBreaching"
  dimensions = {
    Rule   = local.metric_names.login_ip_rate_limit
    WebACL = aws_wafv2_web_acl.waf_acl.name
  }

  alarm_actions = [var.security_sns_topic_global_arn]
  ok_actions    = [var.security_sns_topic_global_arn]
}
