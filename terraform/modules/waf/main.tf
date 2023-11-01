resource "aws_wafv2_ip_set" "main" {
  provider = aws.us-east-1
  count    = var.ip_allowlist == null ? 0 : 1

  name               = "${var.prefix}cloudfront-waf-ipset"
  description        = "${var.prefix}cloudfront-waf-ipset"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = var.ip_allowlist
}

locals {
  # Delta needs file uploads so we'll presumably want a much higher limit than 8KB
  # This does limit the usefulness of the other rules though as they only scan the first 8KB of the body
  excluded_rules = concat(var.excluded_rules, ["SizeRestrictions_BODY"])

  metric_names = {
    main                = replace("${var.prefix}cloudfront-waf-acl", "-", "")
    rate_limit          = replace("${var.prefix}cloudfront-waf-rate-limit", "-", "")
    login_ip_rate_limit = replace("${var.prefix}cloudfront-waf-login-rate-limit", "-", "")
    common              = replace("${var.prefix}cloudfront-waf-common-rules", "-", "")
    bad_inputs          = replace("${var.prefix}cloudfront-waf-bad-inputs", "-", "")
    ip_reputation       = replace("${var.prefix}cloudfront-waf-ip-reputation", "-", "")
    ip_allowlist        = replace("${var.prefix}cloudfront-waf-ip-allowlist", "-", "")
  }
  all_routes_ip_allowlist_enabled    = var.ip_allowlist != null && var.ip_allowlist_uri_path_regex == null
  path_specific_ip_allowlist_enabled = var.ip_allowlist != null && var.ip_allowlist_uri_path_regex != null
  ip_reputation_enabled              = !local.all_routes_ip_allowlist_enabled
  // For the "for_each" argument of dynamic blocks, a list of one item "[{}]" means on, empty list "[]" is off
  all_routes_ip_allowlist_foreach    = local.all_routes_ip_allowlist_enabled ? [{}] : []
  path_specific_ip_allowlist_foreach = local.path_specific_ip_allowlist_enabled ? [{}] : []
  ip_reputation_foreach              = local.ip_reputation_enabled ? [{}] : []
  login_ip_rate_limit_foreach        = var.login_ip_rate_limit_enabled ? [{}] : []
}

output "acl_arn" {
  value = aws_wafv2_web_acl.waf_acl.arn
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

locals {
  # Terraform is buggy around WAF changes, changing this so all the rules are updated will often fix it
  # https://github.com/hashicorp/terraform-provider-aws/issues/23992

  priority_base = 300
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
    metric_name                = local.metric_names.main
    sampled_requests_enabled   = true
  }

  rule {
    name     = "overall-rate-limit"
    priority = 10 + local.priority_base

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.per_ip_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = local.metric_names.rate_limit
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-common-rules"
    priority = 20 + local.priority_base

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        dynamic "rule_action_override" {
          for_each = local.excluded_rules
          content {
            action_to_use {
              count {}
            }
            name = rule_action_override.value
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = local.metric_names.common
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-bad-inputs"
    priority = 30 + local.priority_base

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
      metric_name                = local.metric_names.bad_inputs
      sampled_requests_enabled   = true
    }
  }

  custom_response_body {
    key          = "ip_error"
    content      = "This resource is not available to your IP address"
    content_type = "TEXT_PLAIN"
  }

  # Either use the AWS managed IP reputation list, or an explicit allowlist
  dynamic "rule" {
    for_each = local.ip_reputation_foreach
    content {
      name     = "aws-ip-reputation"
      priority = 40 + local.priority_base

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesAmazonIpReputationList"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = local.metric_names.ip_reputation
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = local.all_routes_ip_allowlist_foreach
    content {
      name     = "ip-allowlist"
      priority = 50 + local.priority_base
      action {
        block {
          custom_response {
            custom_response_body_key = "ip_error"
            response_code            = 403
          }
        }
      }

      statement {
        not_statement {
          statement {
            ip_set_reference_statement {
              arn = aws_wafv2_ip_set.main[0].arn
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = local.metric_names.ip_allowlist
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = local.path_specific_ip_allowlist_foreach
    content {
      // Should never be on at the same time as the "ip-allowlist" rule above
      name     = "ip-allowlist-path"
      priority = 50 + local.priority_base
      action {
        block {
          custom_response {
            custom_response_body_key = "ip_error"
            response_code            = 403
          }
        }
      }

      // Block requests that match ip_restricted_paths unless they are on the IP allowlist
      statement {
        and_statement {
          statement {
            not_statement {
              statement {
                ip_set_reference_statement {
                  arn = aws_wafv2_ip_set.main[0].arn
                }
              }
            }
          }
          statement {
            regex_pattern_set_reference_statement {
              arn = aws_wafv2_regex_pattern_set.ip_restricted_paths[0].arn
              field_to_match {
                uri_path {}
              }
              text_transformation {
                priority = 0
                type     = "URL_DECODE"
              }
              text_transformation {
                priority = 1
                type     = "NORMALIZE_PATH"
              }
              text_transformation {
                priority = 2
                type     = "LOWERCASE"
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = local.metric_names.ip_allowlist
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = local.login_ip_rate_limit_foreach
    content {
      name     = "login-ip-rate-limit"
      priority = 70 + local.priority_base

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.login_ip_rate_limit
          aggregate_key_type = "IP"
          scope_down_statement {
            regex_pattern_set_reference_statement {
              arn = aws_wafv2_regex_pattern_set.waf_rate_limit_urls[0].arn
              field_to_match {
                uri_path {}
              }
              text_transformation {
                priority = 0
                type     = "URL_DECODE"
              }
            }
          }
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = local.metric_names.login_ip_rate_limit
        sampled_requests_enabled   = true
      }
    }
  }
}

resource "aws_wafv2_regex_pattern_set" "ip_restricted_paths" {
  provider = aws.us-east-1
  count    = var.ip_allowlist_uri_path_regex == null ? 0 : 1
  name     = "${var.prefix}cloudfront-waf-ip-restrict-patterns"
  scope    = "CLOUDFRONT"

  dynamic "regular_expression" {
    for_each = var.ip_allowlist_uri_path_regex
    content {
      regex_string = regular_expression.value
    }
  }
}

resource "aws_wafv2_regex_pattern_set" "waf_rate_limit_urls" {
  provider = aws.us-east-1
  count    = var.login_ip_rate_limit_enabled ? 1 : 0
  name     = "${var.prefix}cloudfront-waf-regex-patterns"
  scope    = "CLOUDFRONT"

  regular_expression {
    regex_string = "/login"
  }

  regular_expression {
    regex_string = "/forgot-password"
  }

  regular_expression {
    regex_string = "/reset-password"
  }
}
