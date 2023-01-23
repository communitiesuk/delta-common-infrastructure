# Inspired by the app_logs in the `delta` project.

locals {
  app_log_group_name = "marklogic-${var.environment}"
  ssm_log_group_name = "marklogic-ssm-${var.environment}"
}

resource "aws_cloudwatch_log_group" "main" {
  name              = local.app_log_group_name
  retention_in_days = var.log_retention_in_days
  kms_key_id        = aws_kms_key.app_logs_encryption_key.arn
}

resource "aws_cloudwatch_log_group" "ssm" {
  name              = local.ssm_log_group_name
  retention_in_days = var.log_retention_in_days
  kms_key_id        = aws_kms_key.app_logs_encryption_key.arn
}

resource "aws_kms_key" "app_logs_encryption_key" {
  description         = "Marklogic app cloudwatch logs - ${var.environment}"
  enable_key_rotation = true
  policy = templatefile("${path.module}/templates/logging_kms_policy.json", {
    account_id        = data.aws_caller_identity.current.account_id
    region            = data.aws_region.current.name
    log_group_pattern = "marklogic-*${var.environment}"
  })
}

resource "aws_kms_alias" "app_logs_encryption_key" {
  name          = "alias/marklogic-logs-encryption-${var.environment}"
  target_key_id = aws_kms_key.app_logs_encryption_key.id
}

resource "aws_ssm_parameter" "cloudwatch_config" {
  name        = "/marklogic/${var.environment}/cloudwatch/config"
  description = "cloudwatch_config.json for the MarkLogic servers"
  type        = "String"
  value = templatefile("${path.module}/templates/cloudwatch_config.json", {
    environment        = var.environment
    app_log_group_name = local.app_log_group_name
    ssm_log_group_name = local.ssm_log_group_name
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.ml_iam_role.name
}

resource "aws_ssm_association" "install_cloudwatch_agent" {
  name             = aws_ssm_document.couldwatch_agent.name
  association_name = "Install-CloudwatchAgent-${var.environment}"
  parameters = {
    SsmParameterName = aws_ssm_parameter.cloudwatch_config.name
  }
  targets {
    key    = "tag:marklogic:stack:name"
    values = [local.stack_name]
  }
}

resource "aws_ssm_document" "couldwatch_agent" {
  name            = "ConfigureCloudwatchAgent-${var.environment}"
  document_format = "YAML"
  document_type   = "Command"

  content = file("${path.module}/templates/cloudwatch_agent_ssm_doc.yml")
}

