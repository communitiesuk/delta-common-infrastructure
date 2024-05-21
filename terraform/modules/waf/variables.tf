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

variable "ip_allowlist_uri_path_regex" {
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

variable "alarms_sns_topic_global_arn" {
  description = "SNS topic ARN to send alarm notifications to"
  type        = string
}

variable "security_sns_topic_global_arn" {
  description = "SNS topic ARN to send security notifications to"
  type        = string
}

variable "blocked_ip_addresses" {
  type    = list(string)
  default = ["13.41.22.180/32", "13.42.130.170/32"]
}
