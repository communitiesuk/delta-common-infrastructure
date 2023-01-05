variable "organisation_account_id" {
  type = string
}

variable "environment" {
  type = string
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
