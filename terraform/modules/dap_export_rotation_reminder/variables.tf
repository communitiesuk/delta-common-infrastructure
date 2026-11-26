variable "environment" {
  type = string
}

variable "secret_arn" {
  type = string
}

variable "emails" {
  type = set(string)

  validation {
    condition     = length(var.emails) >= 1 && length(var.emails) <= 50
    error_message = "SES requires between 1 and 50 recipients for a single reminder email."
  }
}

variable "sender" {
  type = object({
    identity_arn = string
    address      = string
  })
  nullable = false
}

variable "alarms_topic_arn" {
  type = string
}

variable "log_retention_days" {
  type = number
}
