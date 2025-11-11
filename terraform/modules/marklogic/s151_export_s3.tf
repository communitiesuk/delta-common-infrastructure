locals {
  s151_export_path                          = "/delta/export/s151"
  latest_s151_export_files_lifespan_in_days = 7
  s151_bucket_name                          = "dluhc-delta-s151-export-${var.environment}"
  s151_bucket_arn                           = "arn:aws:s3:::${local.s151_bucket_name}"
}

module "s151_export_bucket" {
  source                             = "../s3_bucket"
  bucket_name                        = local.s151_bucket_name
  access_log_bucket_name             = "dluhc-delta-s151-export-access-logs-${var.environment}"
  access_s3_log_expiration_days      = var.s151_export_s3_log_expiration_days
  noncurrent_version_expiration_days = null
  policy                             = length(var.s151_external_canonical_users) == 0 ? "" : data.aws_iam_policy_document.allow_access_s151_bucket.json
}

data "aws_iam_policy_document" "allow_access_s151_bucket" {
  statement {
    principals {
      type        = "AWS"
      identifiers = var.s151_external_role_arns
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketLocation"
    ]

    resources = [
      local.s151_bucket_arn,
      "${local.s151_bucket_arn}/latest/*",
    ]
  }
  dynamic "statement" {
    for_each = length(var.s151_external_canonical_users) > 1 ? [1] : []
    content {
      sid    = "AllowExternalBucketAccess"
      effect = "Allow"
      principals {
        type        = "CanonicalUser"
        identifiers = var.s151_external_canonical_users
      }
      actions = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      resources = [
        local.s151_bucket_arn,
        "${local.s151_bucket_arn}/latest/*",
      ]
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "s151_export" {
  depends_on = [module.s151_export_bucket]

  bucket = module.s151_export_bucket.bucket

  rule {
    id = "expire-old-versions"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = local.latest_s151_export_files_lifespan_in_days
    }

    status = "Enabled"
  }
}

module "s151_export_job_window" {
  source = "../maintenance_window"

  environment       = var.environment
  prefix            = "marklogic-s151-job"
  schedule          = "cron(00 01 ? * * *)"
  subscribed_emails = var.s151_job_notification_emails
}

resource "aws_ssm_maintenance_window_target" "ml_server_s151" {
  window_id     = module.s151_export_job_window.window_id
  name          = "marklogic-s151-s3-upload-${var.environment}"
  description   = "This should contain the MarkLogic servers from the ${var.environment} environment"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:aws:cloudformation:stack-name"
    values = [local.stack_name]
  }
}

# Non sensitive job output
# tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "s151_upload" {
  name              = "${local.app_log_group_base_name}/s151-upload-task"
  retention_in_days = var.patch_cloudwatch_log_expiration_days
}

resource "aws_ssm_maintenance_window_task" "s151_s3_upload" {
  window_id       = module.s151_export_job_window.window_id
  max_concurrency = 1
  max_errors      = 2 # It should succeed on one of the three hosts where the associated MarkLogic jobs have run
  priority        = 1
  task_arn        = "AWS-RunShellScript"
  task_type       = "RUN_COMMAND"
  cutoff_behavior = "CONTINUE_TASK"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.ml_server_s151.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      comment         = "MarkLogic S151 S3 data upload"
      timeout_seconds = 60

      service_role_arn = module.s151_export_job_window.service_role_arn
      notification_config {
        notification_arn    = module.s151_export_job_window.errors_sns_topic_arn
        notification_events = ["TimedOut", "Cancelled", "Failed"]
        notification_type   = "Command"
      }

      parameter {
        name = "commands"
        values = [
          "set -ex",
          "if [ -z \"$(ls ${local.delta_export_path})\" ]; then echo 'Error ${local.delta_export_path} is empty nothing to export'; exit 1; fi",
          "rm -rf /delta/export-workdir/s151 && cp -r ${local.delta_export_path}/. /delta/export-workdir/s151",
          "cd /delta/export-workdir/s151 && echo 'Files to upload' && find . -type f",
          "aws s3 cp --region ${data.aws_region.current.name} /delta/export-workdir/s151 \"s3://${module.s151_export_bucket.bucket}/latest\" --recursive",
          "rm -rf ${local.delta_export_path}/*",
        ]
      }

      cloudwatch_config {
        cloudwatch_log_group_name = aws_cloudwatch_log_group.s151_upload.name
        cloudwatch_output_enabled = true
      }
    }
  }
}
