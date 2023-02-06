# Inspired by the app_logs in the marklogic module.

locals {
  app_log_group_base_name = "${var.environment}/jaspersoft"
  ssm_log_group_name      = "${var.environment}/jaspersoft-ssm"
}

module "jaspersoft_log_group" {
  source         = "../encrypted_log_groups"
  retention_days = var.app_cloudwatch_log_expiration_days

  kms_key_alias_name = "jaspersoft-logs-${var.environment}"
  log_group_names    = [local.app_log_group_base_name, local.ssm_log_group_name]
}

resource "aws_s3_object" "cloudwatch_config" {
  content = templatefile("${path.module}/templates/cloudwatch_config.json.tftpl", {
    environment        = var.environment
    ssm_log_group_name = local.ssm_log_group_name
  })
  bucket = module.config_bucket.bucket
  key    = "cloudwatch_config.json"
}

resource "aws_ssm_association" "install_cloudwatch_agent" {
  depends_on       = [module.jaspersoft_log_group]
  name             = aws_ssm_document.couldwatch_agent.name
  association_name = "Install-CloudwatchAgent-jaspersoft-${var.environment}"
  parameters = {
    ConfigLocation = "s3://${aws_s3_object.cloudwatch_config.bucket}/${aws_s3_object.cloudwatch_config.key}"
  }
  targets {
    key    = "InstanceIds"
    values = [aws_instance.jaspersoft_server.id]
  }
}

resource "aws_ssm_document" "couldwatch_agent" {
  name            = "ConfigureCloudwatchAgentJaspersoft-${var.environment}"
  document_format = "YAML"
  document_type   = "Command"

  content = file("${path.module}/templates/cloudwatch_agent_ssm_doc.yml")
}

