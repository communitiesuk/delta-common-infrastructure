# MarkLogic doesn't have a native way of reporting metrics to CloudWatch.
# We run an XQuery script (scripts/metrics-json.xqy) on the main MarkLogic node
# every five minutes, send the results to CloudWatch logs and then use a metric filter to extract numeric values.

locals {
  metrics_log_group_name = "${local.app_log_group_base_name}-metrics"
  metrics_cron_script = templatefile("${path.module}/scripts/metrics-cron.sh", {
    LOG_GROUP_NAME = local.metrics_log_group_name
    ENVIRONMENT    = var.environment
    AWS_REGION     = data.aws_region.current.name
  })
}

resource "aws_s3_object" "metrics_cron_script" {
  content = local.metrics_cron_script
  etag    = md5(local.metrics_cron_script)
  bucket  = module.config_files_bucket.bucket
  key     = "metrics-cron.sh"
}

resource "aws_s3_object" "metrics_xqy_script" {
  source = "${path.module}/scripts/metrics-json.xqy"
  etag   = filemd5("${path.module}/scripts/metrics-json.xqy")
  bucket = module.config_files_bucket.bucket
  key    = "metrics-json.xqy"
}

resource "aws_ssm_association" "setup_metrics_cron" {
  name             = aws_ssm_document.setup_metrics_cron.name
  association_name = "MarkLogic-MetricsSetup-${var.environment}"
  parameters = {
    ShellScriptLocation  = "s3://${aws_s3_object.metrics_cron_script.bucket}/${aws_s3_object.metrics_cron_script.key}"
    XQueryScriptLocation = "s3://${aws_s3_object.metrics_xqy_script.bucket}/${aws_s3_object.metrics_xqy_script.key}"
  }

  targets {
    key    = "tag:marklogic:stack:name"
    values = [local.stack_name]
  }

  targets {
    key    = "tag:Name"
    values = [var.host_names[0]]
  }

  depends_on = [module.marklogic_log_group]
  lifecycle {
    replace_triggered_by = [
      aws_ssm_document.setup_metrics_cron.content,
      aws_s3_object.metrics_cron_script.etag,
      aws_s3_object.metrics_xqy_script.etag,
    ]
  }
}

resource "aws_ssm_document" "setup_metrics_cron" {
  name            = "MarkLogic-ConfigureMetricsCron-${var.environment}"
  document_format = "YAML"
  document_type   = "Command"

  content = file("${path.module}/templates/metrics_config_ssm_doc.yml")
}

resource "aws_cloudwatch_log_metric_filter" "cron_metrics_filter" {
  name           = "${var.environment}-marklogic-scipted-metrics"
  log_group_name = local.metrics_log_group_name
  pattern        = "{ $.value >= 0 }"

  metric_transformation {
    name      = "scripted-metrics"
    namespace = "${var.environment}/MarkLogic"
    value     = "$.value"
    unit      = "None"
    dimensions = {
      "metric" : "$.metric"
    }
  }

  depends_on = [module.marklogic_log_group]
}
