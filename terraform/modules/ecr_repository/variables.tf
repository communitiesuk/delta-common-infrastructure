variable "repo_name" {
}

variable "dev_aws_account_id" {
  default = "486283582667"
}

variable "push_user" {
  description = "IAM user who should have push permissions"
}

variable "kms_alias" {
  description = "Alias name for the repository's KMS key"
}