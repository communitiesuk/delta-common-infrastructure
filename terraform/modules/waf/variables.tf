variable "prefix" {
  type = string
}

variable "excluded_rules" {
  description = "Rules to be excluded from AWSManagedRulesCommonRuleSet"
  type        = list(string)
  default     = []
}

variable "ip_allowlist" {
  type    = list(string)
  default = null
}

variable "per_ip_rate_limit" {
  type        = number
  description = "Requests per five minutes"
}

variable "cloudwatch_log_expiration_days" {
  type = number
}

variable "login_ip_rate_limit" {
  type        = number
  default     = 100
  description = "The per-IP rate limit enforced by AWS WAF in requests per five minutes to the login page"
}

variable "login_ip_rate_limit_enabled" {
  type    = bool
  default = false
}

variable "alarms_sns_topic_global_arn" {
  description = "SNS topic ARN to send alarm notifications to"
  type        = string
}
