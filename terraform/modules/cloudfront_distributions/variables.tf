variable "base_domains" {
  type = list(string)
}

variable "environment" {
  type = string
}

variable "enable_ip_allowlists" {
  type    = bool
  default = true
}

variable "all_distribution_ip_allowlist" {
  type = list(string)
}

variable "waf_per_ip_rate_limit" {
  type        = number
  default     = 500
  description = "The per-IP rate limit enforced by AWS WAF in requests per five minutes"
}

variable "apply_aws_shield_to_delta_website" {
  type = bool
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
  })
}
