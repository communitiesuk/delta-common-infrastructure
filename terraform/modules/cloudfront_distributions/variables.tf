variable "base_domains" {
  type = list(string)
}

variable "environment" {
  type = string
}

variable "waf_per_ip_rate_limit" {
  type        = number
  default     = 500
  description = "The per-IP rate limit enforced by AWS WAF in requests per five minutes"
}

variable "apply_aws_shield" {
  type = bool
}

variable "waf_cloudwatch_log_expiration_days" {
  type = number
}

variable "cloudfront_access_s3_log_expiration_days" {
  type = number
}

variable "delta" {
  type = object({
    alb = object({
      cloudfront_key = string
      dns_name       = string
    })
    domain = optional(object({
      aliases             = list(string)
      acm_certificate_arn = string
    }))
    disable_geo_restriction = optional(bool)
    ip_allowlist            = optional(list(string)) # Leave null to disable IP restrictions
  })
}

variable "api" {
  type = object({
    alb = object({
      cloudfront_key = string
      dns_name       = string
    })
    domain = optional(object({
      aliases             = list(string)
      acm_certificate_arn = string
    }))
    disable_geo_restriction = optional(bool)
    ip_allowlist            = optional(list(string))
  })
}

variable "keycloak" {
  type = object({
    alb = object({
      cloudfront_key = string
      dns_name       = string
    })
    domain = optional(object({
      aliases             = list(string)
      acm_certificate_arn = string
    }))
    disable_geo_restriction = optional(bool)
    ip_allowlist            = optional(list(string))
  })
}

variable "cpm" {
  type = object({
    alb = object({
      cloudfront_key = string
      dns_name       = string
    })
    domain = optional(object({
      aliases             = list(string)
      acm_certificate_arn = string
    }))
    disable_geo_restriction = optional(bool)
    ip_allowlist            = optional(list(string))
  })
}

variable "jaspersoft" {
  type = object({
    alb = object({
      cloudfront_key = string
      dns_name       = string
    })
    domain = optional(object({
      aliases             = list(string)
      acm_certificate_arn = string
    }))
    disable_geo_restriction = optional(bool)
    ip_allowlist            = optional(list(string))
  })
}
