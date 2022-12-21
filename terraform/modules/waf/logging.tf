variable "log_group_suffix" {
  type = string
}

# tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "main" {
  provider = aws.us-east-1

  name              = "aws-waf-logs-${var.log_group_suffix}"
  retention_in_days = 30
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  provider = aws.us-east-1

  log_destination_configs = [aws_cloudwatch_log_group.main.arn]
  resource_arn            = aws_wafv2_web_acl.waf_acl.arn

  logging_filter {
    default_behavior = "DROP"
    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ALL"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }
    }
  }

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
}
