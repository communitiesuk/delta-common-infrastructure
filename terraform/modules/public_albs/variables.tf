
variable "vpc" {
  type = object({
    id         = string
    cidr_block = string
  })
}

variable "environment" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "certificates" {
  description = "Unvalidated certificates, used for the auth ALB listener and re-exported as an output"
  type = map(object({
    arn            = string
    primary_domain = string
  }))
}

variable "apply_aws_shield_to_delta_alb" {
  type = bool
}

variable "alb_s3_log_expiration_days" {
  type = number
}

variable "auth_domain" {
  type = string
}
