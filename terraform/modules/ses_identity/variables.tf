variable "email_cloudwatch_log_expiration_days" {
  type = number
}

variable "environment" {
  type = string
}

variable "domain" {
  type = string
}

variable "alarms_sns_topic_arn" {
  description = "SNS topic ARN to send alarm notifications to"
  type        = string
}

variable "cloudwatch_suffix" {
  description = "Optional suffix for names of cloudwatch log groups and related lambdas"
  type        = string
  default     = ""
}
