variable "email_cloudwatch_log_expiration_days" {
  type = number
}

variable "environment" {
  type = string
}

variable "domain" {
  type = string
}

variable "bounce_complaint_notification_emails" {
  type = list(string)
}
