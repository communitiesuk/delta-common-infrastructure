data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

variable "kms_key_alias_name" {
  type = string
}

variable "log_group_names" {
  type = list(string)
}

variable "retention_days" {
  type = number
}

output "log_group_names" {
  value = [for lg in aws_cloudwatch_log_group.logs : lg.name]
}

output "log_group_arns" {
  value = [for lg in aws_cloudwatch_log_group.logs : lg.arn]
}

resource "aws_kms_key" "logs" {
  enable_key_rotation = true
  description         = var.kms_key_alias_name
  policy = templatefile("${path.module}/logging_kms_policy.json", {
    account_id      = data.aws_caller_identity.current.account_id
    region          = data.aws_region.current.name
    log_group_names = var.log_group_names
  })
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.kms_key_alias_name}"
  target_key_id = aws_kms_key.logs.key_id
}

resource "aws_cloudwatch_log_group" "logs" {
  for_each          = toset(var.log_group_names)
  name              = each.value
  retention_in_days = var.retention_days
  kms_key_id        = aws_kms_key.logs.arn

  lifecycle {
    prevent_destroy = true
  }
}
