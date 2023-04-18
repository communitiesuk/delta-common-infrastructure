data "aws_region" "current" {}

resource "aws_cloudwatch_dashboard" "ses" {
  dashboard_name = "ses"

  dashboard_body = jsonencode(
    {
      widgets = [
        {
          type = "metric",
          properties = {
            "metrics" : [
              ["AWS/SES", "Send"]
            ],
            "region" : data.aws_region.current.name,
            "stat" : "Sum",
            "liveData" : false,
            "title" : "Send",
            "period" : 900,
            "view" : "timeSeries",
            "stacked" : false,
            "yAxis" : {
              "left" : {
                "min" : 0,
                "label" : "Count"
              }
            }
          }
          height = 6
          width  = 8
          x      = 0
          y      = 0
        },
        {
          type = "metric",
          properties = {
            "metrics" : [
              ["AWS/SES", "Delivery"]
            ],
            "region" : data.aws_region.current.name,
            "stat" : "Sum",
            "liveData" : false,
            "title" : "Delivery",
            "period" : 900,
            "view" : "timeSeries",
            "stacked" : false,
            "yAxis" : {
              "left" : {
                "min" : 0,
                "label" : "Count"
              }
            }
          }
          height = 6
          width  = 8
          x      = 8
          y      = 0
        },
        {
          type = "metric",
          properties = {
            "metrics" : [
              ["AWS/SES", "Bounce", { "color" : "#d62728" }]
            ],
            "region" : data.aws_region.current.name,
            "stat" : "Sum",
            "liveData" : false,
            "title" : "Bounce",
            "period" : 900,
            "view" : "timeSeries",
            "stacked" : false,
            "yAxis" : {
              "left" : {
                "min" : 0,
                "label" : "Count"
              }
            }
          }
          height = 6
          width  = 8
          x      = 16
          y      = 0
        },
        {
          type = "metric",
          properties = {
            "metrics" : [
              ["AWS/SES", "Complaint", { "color" : "#d62728" }]
            ],
            "region" : data.aws_region.current.name,
            "stat" : "Sum",
            "liveData" : false,
            "title" : "Complaint",
            "period" : 900,
            "view" : "timeSeries",
            "stacked" : false,
            "yAxis" : {
              "left" : {
                "min" : 0,
                "label" : "Count"
              }
            }
          }
          height = 6
          width  = 8
          x      = 0
          y      = 6
        },
        {
          type = "metric",
          properties = {
            "metrics" : [
              ["AWS/SES", "Reject", { "color" : "#d62728" }]
            ],
            "region" : data.aws_region.current.name,
            "stat" : "Sum",
            "liveData" : false,
            "title" : "Reject",
            "period" : 900,
            "view" : "timeSeries",
            "stacked" : false,
            "yAxis" : {
              "left" : {
                "min" : 0,
                "label" : "Count"
              }
            }
          }
          height = 6
          width  = 8
          x      = 8
          y      = 6
        },
        {
          type = "metric",
          properties = {
            "metrics" : [
              ["AWS/SES", "RenderingFailure", { "color" : "#d62728" }]
            ],
            "region" : data.aws_region.current.name,
            "stat" : "Sum",
            "liveData" : false,
            "title" : "Rendering Failure",
            "period" : 900,
            "view" : "timeSeries",
            "stacked" : false,
            "yAxis" : {
              "left" : {
                "min" : 0,
                "label" : "Count"
              }
            }
          }
          height = 6
          width  = 8
          x      = 16
          y      = 6
        },
        {
          type = "metric",
          properties = {
            "metrics" : [
              ["AWS/SES", "Reputation.BounceRate"]
            ],
            "region" : data.aws_region.current.name,
            "stat" : "Average",
            "liveData" : false,
            "title" : "Bounce rate",
            "period" : 900,
            "view" : "timeSeries",
            "stacked" : false,
            "yAxis" : {
              "left" : {
                "min" : 0,
                "max" : 1,
              }
            }
          }
          height = 6
          width  = 8
          x      = 0
          y      = 12
          }, {
          type = "metric",
          properties = {
            "metrics" : [
              ["AWS/SES", "Reputation.ComplaintRate"]
            ],
            "region" : data.aws_region.current.name,
            "stat" : "Average",
            "liveData" : false,
            "title" : "Complaint rate",
            "period" : 900,
            "view" : "timeSeries",
            "stacked" : false,
            "yAxis" : {
              "left" : {
                "min" : 0,
                "max" : 1,
              }
            }
          }
          height = 6
          width  = 8
          x      = 8
          y      = 12
        },
        {
          type = "metric",
          properties = {
            "title" : "Alarm",
            "annotations" : {
              "alarms" : [aws_cloudwatch_metric_alarm.ses_send_errors.arn]
            },
            "liveData" : false,
            "start" : "-PT3H",
            "end" : "PT0H",
            "region" : data.aws_region.current.name,
            "view" : "timeSeries",
            "stacked" : false,
            "yAxis" : {
              "left" : {
                "min" : 0
              }
            }
          }
          height = 6
          width  = 8
          x      = 16
          y      = 12
        },
      ]
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "ses_send_errors" {
  alarm_name          = "ses-email-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  threshold           = "10"
  alarm_description   = "Problem sending emails, see SES dashboard"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "sum_errors"
    expression  = "SUM(METRICS())"
    label       = "Sum Errors"
    return_data = "true"
  }

  metric_query {
    id = "bounce"
    metric {
      metric_name = "Bounce"
      namespace   = "AWS/SES"
      period      = "900"
      stat        = "Sum"
    }
  }

  metric_query {
    id = "reject"
    metric {
      metric_name = "Reject"
      namespace   = "AWS/SES"
      period      = "900"
      stat        = "Sum"
    }
  }

  metric_query {
    id = "complaint"
    metric {
      metric_name = "Complaint"
      namespace   = "AWS/SES"
      period      = "900"
      stat        = "Sum"
    }
  }

  metric_query {
    id = "rendering_failure"
    metric {
      metric_name = "RenderingFailure"
      namespace   = "AWS/SES"
      period      = "900"
      stat        = "Sum"
    }
  }

  alarm_actions = [var.alarms_sns_topic_arn]
  ok_actions    = [var.alarms_sns_topic_arn]
}

variable "alarms_sns_topic_arn" {
  description = "SNS topic ARN to send alarm notifications to"
  type        = string
}
