resource "aws_waf_rate_based_rule" "overall_rate_limit" {
  name        = "${var.prefix}cloudfront-waf-overall-rate-limit-${var.environment}"
  metric_name = replace("${var.prefix}cloudfront-waf-overall-rate-limit-${var.environment}", "-", "")

  rate_key   = "IP"
  rate_limit = 500
}

# WAF rules adapted from https://github.com/binbashar/terraform-aws-waf-owasp/tree/v1.0.1/modules/waf-global (MIT License)
resource "aws_waf_rule" "xss_rule" {
  name        = "${var.prefix}cloudfront-waf-xss-${var.environment}"
  metric_name = replace("${var.prefix}cloudfront-waf-xss-${var.environment}", "-", "")

  predicates {
    data_id = aws_waf_xss_match_set.xss_match_set.id
    negated = false
    type    = "XssMatch"
  }
}

resource "aws_waf_xss_match_set" "xss_match_set" {
  name = "${var.prefix}cloudfront-waf-xss-match-set-${var.environment}"

  xss_match_tuples {
    text_transformation = "HTML_ENTITY_DECODE"

    field_to_match {
      type = "BODY"
    }
  }

  xss_match_tuples {
    text_transformation = "URL_DECODE"

    field_to_match {
      type = "BODY"
    }
  }

  xss_match_tuples {
    text_transformation = "HTML_ENTITY_DECODE"

    field_to_match {
      type = "URI"
    }
  }

  xss_match_tuples {
    text_transformation = "URL_DECODE"

    field_to_match {
      type = "URI"
    }
  }

  xss_match_tuples {
    text_transformation = "HTML_ENTITY_DECODE"

    field_to_match {
      type = "QUERY_STRING"
    }
  }

  xss_match_tuples {
    text_transformation = "URL_DECODE"

    field_to_match {
      type = "QUERY_STRING"
    }
  }

  xss_match_tuples {
    text_transformation = "HTML_ENTITY_DECODE"

    field_to_match {
      type = "HEADER"
      data = "cookie"
    }
  }

  xss_match_tuples {
    text_transformation = "URL_DECODE"

    field_to_match {
      type = "HEADER"
      data = "cookie"
    }
  }
}

resource "aws_waf_rule" "traversal" {
  name        = "${var.prefix}cloudfront-waf-traversal-${var.environment}"
  metric_name = replace("${var.prefix}cloudfront-waf-traversal-${var.environment}", "-", "")

  predicates {
    data_id = aws_waf_byte_match_set.traversal.id
    negated = false
    type    = "ByteMatch"
  }
}

resource "aws_waf_byte_match_set" "traversal" {
  name = "${var.prefix}cloudfront-waf-traversal-${var.environment}"

  byte_match_tuples {
    text_transformation   = "HTML_ENTITY_DECODE"
    target_string         = "://"
    positional_constraint = "CONTAINS"

    field_to_match {
      type = "QUERY_STRING"
    }
  }

  byte_match_tuples {
    text_transformation   = "HTML_ENTITY_DECODE"
    target_string         = "../"
    positional_constraint = "CONTAINS"

    field_to_match {
      type = "QUERY_STRING"
    }
  }

  byte_match_tuples {
    text_transformation   = "URL_DECODE"
    target_string         = "://"
    positional_constraint = "CONTAINS"

    field_to_match {
      type = "QUERY_STRING"
    }
  }

  byte_match_tuples {
    text_transformation   = "URL_DECODE"
    target_string         = "../"
    positional_constraint = "CONTAINS"

    field_to_match {
      type = "QUERY_STRING"
    }
  }

  byte_match_tuples {
    text_transformation   = "HTML_ENTITY_DECODE"
    target_string         = "://"
    positional_constraint = "CONTAINS"

    field_to_match {
      type = "URI"
    }
  }

  byte_match_tuples {
    text_transformation   = "HTML_ENTITY_DECODE"
    target_string         = "../"
    positional_constraint = "CONTAINS"

    field_to_match {
      type = "URI"
    }
  }

  byte_match_tuples {
    text_transformation   = "URL_DECODE"
    target_string         = "://"
    positional_constraint = "CONTAINS"

    field_to_match {
      type = "URI"
    }
  }

  byte_match_tuples {
    text_transformation   = "URL_DECODE"
    target_string         = "../"
    positional_constraint = "CONTAINS"

    field_to_match {
      type = "URI"
    }
  }
}


resource "aws_waf_rule" "ssi_private_files" {
  name        = "${var.prefix}cloudfront-waf-ssi-${var.environment}"
  metric_name = replace("${var.prefix}cloudfront-waf-ssi-${var.environment}", "-", "")

  predicates {
    data_id = aws_waf_byte_match_set.ssi_private_files.id
    negated = false
    type    = "ByteMatch"
  }
}

resource "aws_waf_byte_match_set" "ssi_private_files" {
  name = "${var.prefix}cloudfront-waf-ssi-${var.environment}"

  byte_match_tuples {
    text_transformation   = "LOWERCASE"
    target_string         = ".cfg"
    positional_constraint = "ENDS_WITH"

    field_to_match {
      type = "URI"
    }
  }

  byte_match_tuples {
    text_transformation   = "LOWERCASE"
    target_string         = ".backup"
    positional_constraint = "ENDS_WITH"

    field_to_match {
      type = "URI"
    }
  }

  byte_match_tuples {
    text_transformation   = "LOWERCASE"
    target_string         = ".ini"
    positional_constraint = "ENDS_WITH"

    field_to_match {
      type = "URI"
    }
  }

  byte_match_tuples {
    text_transformation   = "LOWERCASE"
    target_string         = ".conf"
    positional_constraint = "ENDS_WITH"

    field_to_match {
      type = "URI"
    }
  }

  byte_match_tuples {
    text_transformation   = "LOWERCASE"
    target_string         = ".log"
    positional_constraint = "ENDS_WITH"

    field_to_match {
      type = "URI"
    }
  }

  byte_match_tuples {
    text_transformation   = "LOWERCASE"
    target_string         = ".bak"
    positional_constraint = "ENDS_WITH"

    field_to_match {
      type = "URI"
    }
  }

  byte_match_tuples {
    text_transformation   = "LOWERCASE"
    target_string         = ".config"
    positional_constraint = "ENDS_WITH"

    field_to_match {
      type = "URI"
    }
  }

  byte_match_tuples {
    text_transformation   = "LOWERCASE"
    target_string         = ".properties"
    positional_constraint = "ENDS_WITH"

    field_to_match {
      type = "URI"
    }
  }

  byte_match_tuples {
    text_transformation   = "URL_DECODE"
    target_string         = "/includes"
    positional_constraint = "STARTS_WITH"

    field_to_match {
      type = "URI"
    }
  }
}

resource "aws_waf_web_acl" "waf_acl" {
  name        = "${var.prefix}cloudfront-waf-acl-${var.environment}"
  metric_name = replace("${var.prefix}cloudfront-waf-acl-${var.environment}", "-", "")

  default_action {
    type = "ALLOW"
  }

  rules {
    action {
      type = "BLOCK"
    }

    priority = 1
    rule_id  = aws_waf_rate_based_rule.overall_rate_limit.id
    type     = "RATE_BASED"
  }

  rules {
    action {
      type = "BLOCK"
    }

    priority = 2
    rule_id  = aws_waf_rule.xss_rule.id
    type     = "REGULAR"
  }

  rules {
    action {
      type = "BLOCK"
    }

    priority = 3
    rule_id  = aws_waf_rule.traversal.id
    type     = "REGULAR"
  }

  rules {
    action {
      type = "BLOCK"
    }

    priority = 4
    rule_id  = aws_waf_rule.ssi_private_files.id
    type     = "REGULAR"
  }
}
