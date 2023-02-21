locals {
  delta_export_path                    = "/delta/export"
  latest_export_files_lifespan_in_days = 30
}

module "dap_export_bucket" {
  source                             = "../s3_bucket"
  bucket_name                        = "dluhc-delta-dap-export-${var.environment}"
  access_log_bucket_name             = "dluhc-delta-dap-export-access-logs-${var.environment}"
  access_s3_log_expiration_days      = var.dap_export_s3_log_expiration_days
  noncurrent_version_expiration_days = null
  policy                             = data.aws_iam_policy_document.allow_access_from_dap.json
}

data "aws_iam_policy_document" "allow_access_from_dap" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [var.dap_external_role_arn]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketLocation"
    ]

    resources = [
      module.dap_export_bucket.bucket_arn,
      "${module.dap_export_bucket.bucket_arn}/latest/*",
    ]

    # condition {
    #   test     = "IpAddress"
    #   variable = "aws:SourceIp"
    #   values   = ["52.17.138.171/32"]
    # }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "dap_export" {
  depends_on = [module.dap_export_bucket]

  bucket = module.dap_export_bucket.bucket

  rule {
    id = "expire-old-versions"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 180
    }

    status = "Enabled"
  }

  rule {
    id = "latest-folder-expiration"

    filter {
      prefix = "latest/"
    }
    expiration {
      days = local.latest_export_files_lifespan_in_days
    }

    status = "Enabled"
  }
}

module "dap_export_job_window" {
  source = "../maintenance_window"

  environment = var.environment
  prefix      = "marklogic-dap-job"
  schedule    = "cron(00 04 ? * * *)"
}

resource "aws_ssm_maintenance_window_target" "ml_server" {
  window_id     = module.dap_export_job_window.window_id
  name          = "marklogic-dap-s3-upload-${var.environment}"
  description   = "This should contain the MarkLogic servers from the ${var.environment} environment"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:aws:cloudformation:stack-name"
    values = [local.stack_name]
  }
}

resource "aws_ssm_maintenance_window_task" "dap_s3_upload" {
  window_id       = module.dap_export_job_window.window_id
  max_concurrency = 1
  max_errors      = 0
  priority        = 1
  task_arn        = "AWS-RunShellScript"
  task_type       = "RUN_COMMAND"
  cutoff_behavior = "CONTINUE_TASK"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.ml_server.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      comment         = "MarkLogic DAP S3 data upload"
      timeout_seconds = 60

      service_role_arn = module.dap_export_job_window.service_role_arn
      notification_config {
        notification_arn    = module.dap_export_job_window.errors_sns_topic_arn
        notification_events = ["TimedOut", "Cancelled", "Failed"]
        notification_type   = "Command"
      }

      parameter {
        name = "commands"
        values = [
          "set -ex",
          "if [ -z \"$(ls ${local.delta_export_path})\" ]; then echo 'Error ${local.delta_export_path} is empty nothing to export'; exit 1; fi",
          "rm -rf /delta/export-workdir && cp -r ${local.delta_export_path}/. /delta/export-workdir",
          "cd /delta/export-workdir && find . -type f",
          "aws s3 cp --region ${data.aws_region.current.name} /delta/export-workdir \"s3://${module.dap_export_bucket.bucket}/latest\"",
          "aws s3 cp --region ${data.aws_region.current.name} /delta/export-workdir \"s3://${module.dap_export_bucket.bucket}/archive/$(date +%F)\" --recursive",
          "rm -rf ${local.delta_export_path}/*",
        ]
      }
    }
  }
}
