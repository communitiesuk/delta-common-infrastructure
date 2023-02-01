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
