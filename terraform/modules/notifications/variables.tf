variable "environment" {
  description = "test, staging or production"
  type        = string
}

variable "alarm_sns_topic_emails" {
  type = list(string)
}

variable "security_sns_topic_emails" {
  type = list(string)
}
