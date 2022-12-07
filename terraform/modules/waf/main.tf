variable "prefix" {
  type = string
}
variable "excluded_rules" {
  description = "Rules to be excluded from AWSManagedRulesCommonRuleSet"
  type        = list(string)
  default     = []
}

locals {
  # Delta needs file uploads so we'll presumably want a much higher limit than 8KB
  # This does limit the usefulness of the other rules though as they only scan the first 8KB of the body
  excluded_rules = concat(var.excluded_rules, ["SizeRestrictions_BODY"])
}

output "acl_arn" {
  value = aws_wafv2_web_acl.waf_acl.arn
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

resource "aws_wafv2_web_acl" "waf_acl" {
  provider = aws.us-east-1

  name  = "${var.prefix}cloudfront-waf-acl"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = replace("${var.prefix}cloudfront-waf-acl", "-", "")
    sampled_requests_enabled   = true
  }

  rule {
    name     = "overall-rate-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 500
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = replace("${var.prefix}cloudfront-waf-rate-limit", "-", "")
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-common-rules"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        dynamic "excluded_rule" {
          for_each = local.excluded_rules
          content {
            name = excluded_rule.value
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = replace("${var.prefix}cloudfront-waf-common-rules", "-", "")
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-bad-inputs"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = replace("${var.prefix}cloudfront-waf-bad-inputs", "-", "")
      sampled_requests_enabled   = true
    }
  }
}
