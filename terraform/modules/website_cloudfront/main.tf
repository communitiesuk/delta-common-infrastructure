locals {
  cloudfront_key_header = "X-Cloudfront-Key"
}

resource "aws_cloudfront_response_headers_policy" "main" {
  name    = "${var.prefix}cloudfront-policy"
  comment = "Default security headers for responses"

  security_headers_config {
    frame_options {
      frame_option = "SAMEORIGIN"
      override     = false
    }

    referrer_policy {
      referrer_policy = "no-referrer"
      override        = false
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = false
    }
  }

  custom_headers_config {
    items {
      header   = "Permissions-Policy"
      value    = "geolocation=(), interest-cohort=()"
      override = false
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "static_errors" {
  name    = "${var.prefix}cloudfront-policy-static-errors"
  comment = "Headers for static error responses"

  security_headers_config {
    frame_options {
      frame_option = "SAMEORIGIN"
      override     = false
    }

    referrer_policy {
      referrer_policy = "no-referrer"
      override        = false
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = false
    }
  }

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = "no-store"
      override = true
    }
  }
}

resource "aws_cloudfront_distribution" "main" {
  aliases = var.cloudfront_domain == null ? [] : var.cloudfront_domain.aliases

  wait_for_deployment = false

  origin {
    domain_name = var.origin_domain
    origin_id   = "primary"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = var.cloudfront_domain == null ? "http-only" : "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = var.origin_read_timeout
    }

    custom_header {
      name  = local.cloudfront_key_header
      value = var.cloudfront_key
    }
  }

  origin {
    domain_name = module.error_bucket.bucket_regional_domain_name
    origin_id   = "error_origin"

    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  enabled         = true
  is_ipv6_enabled = var.is_ipv6_enabled

  default_cache_behavior {
    allowed_methods  = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "primary"

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }

      headers = ["*"]
    }

    viewer_protocol_policy     = "redirect-to-https"
    min_ttl                    = 0
    default_ttl                = 0
    max_ttl                    = 86400
    response_headers_policy_id = aws_cloudfront_response_headers_policy.main.id
  }

  ordered_cache_behavior {
    allowed_methods            = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods             = ["GET", "HEAD", "OPTIONS"]
    target_origin_id           = "error_origin"
    path_pattern               = "/static_errors/*"
    viewer_protocol_policy     = "redirect-to-https"
    min_ttl                    = 120
    default_ttl                = 120
    max_ttl                    = 86400
    response_headers_policy_id = aws_cloudfront_response_headers_policy.static_errors.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = ["/resources/*", "/public/*", "/govuk/assets/*"]
    iterator = pattern

    content {
      allowed_methods            = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
      cached_methods             = ["GET", "HEAD", "OPTIONS"]
      target_origin_id           = "primary"
      path_pattern               = pattern.value
      viewer_protocol_policy     = "redirect-to-https"
      min_ttl                    = 0
      default_ttl                = 0
      max_ttl                    = 86400
      response_headers_policy_id = aws_cloudfront_response_headers_policy.main.id

      forwarded_values {
        query_string = true
      }
    }
  }

  custom_error_response {
    error_code         = 502
    response_code      = 502
    response_page_path = "/static_errors/error.html"
  }

  custom_error_response {
    error_code         = 503
    response_code      = 503
    response_page_path = "/static_errors/503.html"
  }

  custom_error_response {
    error_code         = 504
    response_code      = 504
    response_page_path = "/static_errors/error.html"
  }

  price_class = "PriceClass_100"
  web_acl_id  = var.waf_acl_arn

  logging_config {
    bucket          = var.access_logs_bucket_domain_name
    include_cookies = false
    prefix          = "${var.access_logs_prefix}/"
  }

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_countries != null ? "whitelist" : "none"
      locations        = var.geo_restriction_countries != null ? var.geo_restriction_countries : []
    }
  }

  tags = {
    Name = "${var.prefix}cloudfront"
  }

  viewer_certificate {
    cloudfront_default_certificate = var.cloudfront_domain == null ? true : false
    acm_certificate_arn            = var.cloudfront_domain == null ? null : aws_acm_certificate_validation.cloudfront_domains[0].certificate_arn
    minimum_protocol_version       = var.cloudfront_domain == null ? "TLSv1" : "TLSv1.2_2021"
    ssl_support_method             = var.cloudfront_domain == null ? null : "sni-only"
  }

  # The DNS records we ask DLUHC to create CNAME to these distributions, so we shouldn't delete them
  retain_on_delete = true
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_shield_protection" "main" {
  count        = var.apply_aws_shield ? 1 : 0
  name         = "Cloudfront Protection"
  resource_arn = aws_cloudfront_distribution.main.arn
}

# It would be convenient to add a aws_route53_health_check and aws_shield_protection_health_check_association
# with the cloudfront distribution here.
# See: https://aws.amazon.com/about-aws/whats-new/2020/02/aws-shield-advanced-now-supports-health-based-detection/
# However, the benefit is minor (possibly faster response to DDoS) and the geo-restriction may interfere.

module "monitoring" {
  source                      = "../cloudfront_monitoring"
  cloudfront_distribution_id  = aws_cloudfront_distribution.main.id
  alarms_sns_topic_global_arn = var.alarms_sns_topic_global_arn
  prefix                      = var.prefix

  error_rate_alarm_threshold_percent = var.error_rate_alarm_threshold_percent
}
