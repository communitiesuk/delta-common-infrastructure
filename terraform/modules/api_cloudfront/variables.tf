variable "prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  type = string
}

variable "access_logs_bucket_domain_name" {
  type = string
}

variable "access_logs_prefix" {
  type = string
}

variable "waf_acl_arn" {
  type = string
}

variable "cloudfront_key" {
  type      = string
  sensitive = true
}

variable "origin_domain" {
  type = string
}

variable "is_ipv6_enabled" {
  description = "Set to false to disable ipv6, e.g. if you want to use an allowlist of ipv4 addresses"
  type        = bool
  default     = true
}

variable "cloudfront_domain" {
  type = object({
    aliases             = list(string),
    acm_certificate_arn = string
  })
  default = null
}

variable "geo_restriction_countries" {
  type        = list(string)
  description = "Set to null to disable geo restriction"
}

variable "apply_aws_shield" {
  type = bool
}

variable "swagger_s3_log_expiration_days" {
  type = number
}

variable "alarms_sns_topic_global_arn" {
  description = "SNS topic ARN to send alarm notifications to"
  type        = string
}

variable "server_error_rate_alarm_threshold_percent" {
  description = "Threshold to trigger server error (5xx) alarm in percentage points"
  type        = number
}

variable "client_error_rate_alarm_threshold_percent" {
  description = "Threshold to trigger client error (4xx) alarm in percentage points"
  type        = number
}
