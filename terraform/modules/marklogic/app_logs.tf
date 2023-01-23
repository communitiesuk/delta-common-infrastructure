# Inspired by the app_logs in the `delta` project.

locals {
  app_log_group_name = "marklogic-${var.environment}"
  ssm_log_group_name = "marklogic-ssm-${var.environment}"
}

module "marklogic_log_group" {
  source = "../encrypted_log_groups"

  kms_key_alias_name = "marklogic-logs"
  log_group_names    = [local.app_log_group_name, local.ssm_log_group_name]
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

resource "aws_ssm_association" "install_cloudwatch_agent" {
  name             = aws_ssm_document.couldwatch_agent.name
  association_name = "Install-CloudwatchAgent-MarkLogic-${var.environment}"
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

