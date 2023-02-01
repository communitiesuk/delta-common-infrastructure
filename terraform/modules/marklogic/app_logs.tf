# Inspired by the app_logs in the `delta` project.

locals {
  app_log_group_base_name = "${var.environment}/marklogic"
  ssm_log_group_name      = "${var.environment}/marklogic-ssm"
}

module "marklogic_log_group" {
  source         = "../encrypted_log_groups"
  retention_days = var.app_cloudwatch_log_expiration_days

  kms_key_alias_name = "marklogic-logs-${var.environment}"
  log_group_names = concat(
    [local.ssm_log_group_name],
    flatten([for port_detail in local.log_port_details :
      [
        "${local.app_log_group_base_name}-${port_detail.log_name_fragment}-${port_detail.port}-access",
        "${local.app_log_group_base_name}-${port_detail.log_name_fragment}-${port_detail.port}-error",
        "${local.app_log_group_base_name}-${port_detail.log_name_fragment}-${port_detail.port}-request",
      ]
    ]),
    [
      "${local.app_log_group_base_name}-audit",
      "${local.app_log_group_base_name}-crash",
      "${local.app_log_group_base_name}-error",
      "${local.app_log_group_base_name}-taskserver-error",
      "${local.app_log_group_base_name}-taskserver-request"
    ]
  )
}

module "config_files_bucket" {
  source                 = "../s3_bucket"
  bucket_name            = "${var.environment}-marklogic-config"
  access_log_bucket_name = "${var.environment}-marklogic-config-access-logs"
}

resource "aws_s3_object" "cloudwatch_config" {
  content = templatefile("${path.module}/templates/cloudwatch_config.json.tftpl", {
    environment             = var.environment
    app_log_group_base_name = local.app_log_group_base_name
    ssm_log_group_name      = local.ssm_log_group_name
    log_port_details        = local.log_port_details
  })
  bucket = module.config_files_bucket.bucket
  key    = "cloudwatch_config.json"
}

resource "aws_ssm_association" "install_cloudwatch_agent" {
  depends_on       = [module.marklogic_log_group]
  name             = aws_ssm_document.couldwatch_agent.name
  association_name = "Install-CloudwatchAgent-MarkLogic-${var.environment}"
  parameters = {
    ConfigLocation = "s3://${aws_s3_object.cloudwatch_config.bucket}/${aws_s3_object.cloudwatch_config.key}"
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

