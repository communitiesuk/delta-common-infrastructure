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

variable "marklogic_ami_version" {
  type = string

  validation {
    condition     = var.marklogic_ami_version == "10.0-10.2" || var.marklogic_ami_version == "10.0-9.5"
    error_message = "Only specific versions allowed, configure AMIs for others"
  }
}

variable daily_backup_bucket_arn {
  type = string
  description = "From the main ML module"
}

variable weekly_backup_bucket_arn {
  type = string
  description = "From the main ML module"
}

variable "backup_key" {
  type = string
  description = "From the main ML module, aws_kms_key.ml_backup_bucket_key.arn"
}