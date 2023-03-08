variable "default_tags" {
  type        = map(string)
  description = "Tags to use for each resource"
}

variable "environment" {
  description = "test, staging or production"
  type        = string
}

variable "vpc" {
  description = "The main VPC"
}

variable "instance_type" {
  description = "EC2 instance type for MarkLogic"
  default     = "r5.4xlarge"
}

variable "private_subnets" {
  description = "Three private subnets"
}

variable "private_dns" {
  type = object({
    zone_id     = string
    base_domain = string
  })
}

variable "data_volume" {
  description = "MarkLogic data volume configuration"
  # See https://aws.amazon.com/ebs/general-purpose/
  # https://aws.amazon.com/ebs/pricing/
  # Max IOPS is 16000, max throughput is 1000 MiB/s
  # 3000 IOPS and 125 MiB/s bandwidth is included with the storage cost
  type = object({
    size_gb                = number
    iops                   = number
    throughput_MiB_per_sec = number
  })
}

variable "ebs_backup_error_notification_emails" {
  type = list(string)
}

variable "patch_maintenance_window" {
  type = object({
    window_id            = string
    service_role_arn     = string
    errors_sns_topic_arn = string
  })
}

variable "extra_instance_policy_arn" {
  type        = string
  description = "arn of IAM policy to give instance necessary permissions for access via Session Manager"
}

variable "app_cloudwatch_log_expiration_days" {
  type = number
}

variable "patch_cloudwatch_log_expiration_days" {
  type = number
}

variable "config_s3_log_expiration_days" {
  type = number
}

variable "backup_s3_log_expiration_days" {
  type = number
}

variable "dap_export_s3_log_expiration_days" {
  type = number
}

variable "alarms_sns_topic_arn" {
  description = "SNS topic ARN to send alarm notifications to"
  type        = string
}

variable "data_disk_usage_alarm_threshold_percent" {
  description = "Percentage of disk utilisation that triggers the alarm"
  type        = number
}

variable "dap_external_role_arn" {
  type = string
}

variable "marklogic_ami_version" {
  type = string

  validation {
    condition     = var.marklogic_ami_version == "10.0-9.2" || var.marklogic_ami_version == "10.0-9.5"
    error_message = "Only specific versions allowed, configure AMIs for others"
  }
}
