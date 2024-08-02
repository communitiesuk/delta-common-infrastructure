# Unvalidated SSL certificates for one or more base domains

variable "primary_domain" {
  description = "For production this would be communities.gov.uk"
  type        = string
}

variable "secondary_domains" {
  type    = list(string)
  default = []
}

variable "validate_and_check_renewal" {
  type = bool
}

locals {
  all_domains = concat([var.primary_domain], var.secondary_domains)
  subdomains = {
    delta    = "delta"
    api      = "api.delta"
    keycloak = "auth.delta"
    cpm      = "cpm"
  }
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "cloudfront_certs" {
  for_each = local.subdomains
  provider = aws.us-east-1

  domain_name               = "${each.value}.${var.primary_domain}"
  subject_alternative_names = [for domain in local.all_domains : "${each.value}.${domain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cloudfront_certs" {
  for_each        = var.validate_and_check_renewal ? local.subdomains : {}
  provider        = aws.us-east-1
  certificate_arn = aws_acm_certificate.cloudfront_certs[each.key].arn

  lifecycle {
    postcondition {
      condition     = aws_acm_certificate.cloudfront_certs[each.key].renewal_eligibility == "ELIGIBLE"
      error_message = "Not eligible for renewal: ${each.value} is ${aws_acm_certificate.cloudfront_certs[each.key].renewal_eligibility}"
    }
  }
}

output "cloudfront_certs" {
  value = { for key, subdomain in local.subdomains : key => {
    arn            = aws_acm_certificate.cloudfront_certs[key].arn
    primary_domain = "${subdomain}.${var.primary_domain}"
    }
  }
}

resource "aws_acm_certificate" "alb_certs" {
  for_each = local.subdomains

  domain_name               = "${each.value}.${var.primary_domain}"
  subject_alternative_names = [for domain in local.all_domains : "${each.value}.${domain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "alb_certs" {
  for_each        = var.validate_and_check_renewal ? local.subdomains : {}
  certificate_arn = aws_acm_certificate.alb_certs[each.key].arn

  lifecycle {
    postcondition {
      condition     = aws_acm_certificate.alb_certs[each.key].renewal_eligibility == "ELIGIBLE"
      error_message = "Not eligible for renewal: ${each.value} is ${aws_acm_certificate.alb_certs[each.key].renewal_eligibility}"
    }
  }
}

output "alb_certs" {
  value = { for key, subdomain in local.subdomains : key => {
    arn            = aws_acm_certificate.alb_certs[key].arn
    primary_domain = "${subdomain}.${var.primary_domain}"
    }
  }
}

output "required_validation_records" {
  value = [for record in toset(flatten([
    [for cert in aws_acm_certificate.cloudfront_certs : cert.domain_validation_options],
    [for cert in aws_acm_certificate.alb_certs : cert.domain_validation_options],
    ])) : {
    record_name  = record.resource_record_name
    record_type  = record.resource_record_type
    record_value = record.resource_record_value
  }]
}
