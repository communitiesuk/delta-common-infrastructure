variable "organisation_account_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "session_manager_key_arn" {
  type = string
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
