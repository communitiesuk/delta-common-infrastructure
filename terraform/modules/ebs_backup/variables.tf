variable "environment" {
  type = string
}

variable "ebs_backup_error_notification_emails" {
  type = list(string)
}

variable "system_drive_backup_schedule" {
  type    = string
  default = "cron(0 23 ? * FRI *)"
}

variable "system_drive_backup_retention_days" {
  type    = number
  default = 14
}
