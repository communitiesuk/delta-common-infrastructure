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

variable "ebs_backup_role_arn" {
  type = string
}

variable "ebs_backup_completed_sns_topic_arn" {
  type = string
}

variable "dap_job_notification_emails" {
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

variable "dap_external_role_arns" {
  type = list(string)
}

variable "dap_external_canonical_users" {
  description = "AWS service accounts that we wish to have access to DAP S3 bucket (read-only)"
  type        = list(string)
  default     = []
}

variable "marklogic_ami_version" {
  type = string

  validation {
    condition     = var.marklogic_ami_version == "10.0-10.2" || var.marklogic_ami_version == "10.0-9.5"
    error_message = "Only specific versions allowed, configure AMIs for others"
  }
}

variable "backup_replication_bucket" {
  type = object({
    arn  = string
    name = string
  })
}

variable "weekly_backup_bucket_retention_days" {
  type        = number
  default     = 10
  description = "Number of days to keep weekly backups in their original bucket before adding a delete marker. The weekly backup bucket is replicated, so this shouldn't need to be very long."
}

variable "iam_github_openid_connect_provider_arn" {
  type = string
}

variable "ses_deploy_secret_arns" {
  type        = list(string)
  description = "List of arns of the kms keys for SES credentials"
}
