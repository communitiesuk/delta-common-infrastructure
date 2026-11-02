variable "environment" {
  type = string
}

variable "private_subnet" {
  type = object({
    id         = string
    cidr_block = string
  })
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

variable "public_dns" {
  type = object({
    zone_id     = string
    base_domain = string
  })
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "ses_user" {
  type = object({
    smtp_username = string
    smtp_password = string
  })
}

variable "patch_maintenance_window" {
  type = object({
    window_id            = string
    service_role_arn     = string
    errors_sns_topic_arn = string
  })
}

variable "patch_cloudwatch_log_expiration_days" {
  type = number
}
