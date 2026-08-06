variable "instance_type" {
  default = "t3.large"
}

variable "environment" {
  description = "test, staging or prod"
}

variable "subnet_id" {
  type = string
}

variable "github_token" {
  description = "short-lived token to register the runner with the repo"
  type        = string
}

variable "vpc" {
  type = object({
    id         = string
    cidr_block = string
  })
}

variable "ssh_ingress_sg_id" {
  type        = string
  description = "Security group id to allow SSH ingress from"
}

variable "private_dns" {
  type = object({
    zone_id     = string
    base_domain = string
  })
}

variable "extra_instance_policy_arn" {
  type = string
}

variable "cloudwatch_log_expiration_days" {
  type = number
}

variable "daily_backup_bucket_arn" {
  type        = string
  description = "ARN of the MarkLogic daily backup S3 bucket"
}

variable "weekly_backup_bucket_arn" {
  type        = string
  description = "ARN of the MarkLogic weekly backup S3 bucket"
}

variable "locked_backup_replication_bucket_arn" {
  type        = string
  description = "ARN of the object-locked backup replication S3 bucket"
}

variable "backup_key_arn" {
  type        = string
  description = "KMS key ARN used to encrypt MarkLogic backup buckets"
}
