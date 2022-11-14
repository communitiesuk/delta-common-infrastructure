module "dap_export_bucket" {
  source = "../s3_bucket"

  bcuket_name            = "dluhc-delta-dap-export-${var.environment}"
  access_log_bucket_name = "dluhc-delta-dap-export-access-logs-${var.environment}"
}

resource "aws_ssm_maintenance_window" "dap_s3_upload" {
  name              = "marklogic-dap-s3-upload-${var.environment}"
  schedule          = "cron(00 06 ? * * *)" # 6 AM every day
  schedule_timezone = "Etc/UTC"
  duration          = 2
  cutoff            = 1
}

resource "aws_ssm_maintenance_window_target" "ml_server" {
  window_id     = aws_ssm_maintenance_window.dap_s3_upload.id
  name          = "marklogic-dap-s3-upload-${var.environment}"
  description   = "This should contain one MarkLogic server from the ${var.environment} environment"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:Name"
    values = ["MarkLogic-ASG-1"]
  }

  targets {
    key    = "tag:environment"
    values = [var.environment]
  }
}

resource "aws_ssm_maintenance_window_task" "dap_s3_upload" {
  window_id       = aws_ssm_maintenance_window.dap_s3_upload.id
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

      service_role_arn = aws_iam_role.dap_sns_publish.arn
      notification_config {
        notification_arn    = aws_sns_topic.dap_s3_upload_notifications.arn
        notification_events = ["TimedOut", "Cancelled", "Failed"]
        notification_type   = "Command"
      }

      parameter {
        name = "commands"
        # TODO DT-23: Confirm location once ML job is set up
        values = ["aws s3 cp /export-data \"s3://${module.dap_export_bucket.bucket}/data\" --recursive"]
      }
    }
  }
}

# SNS topic for errors with the maintenance window job. Non-sensitive.
# tfsec:ignore:aws-sns-enable-topic-encryption
resource "aws_sns_topic" "dap_s3_upload_notifications" {
  name = "marklogic-dap-s3-upload-errors-${var.environment}"
}

# TODO DT-49: Add subscription

resource "aws_iam_role" "dap_sns_publish" {
  name = "marklogic-dap-sns-publish-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dap_sns_publish" {
  role       = aws_iam_role.dap_sns_publish.name
  policy_arn = aws_iam_policy.dap_sns_publish.arn
}

resource "aws_iam_policy" "dap_sns_publish" {
  name        = "marklogic-dap-sns-publish-${var.environment}"
  description = "Used by SSM to push notifications when MarkLogic DAP upload fails"

  policy = data.aws_iam_policy_document.dap_sns_publish.json
}

data "aws_iam_policy_document" "dap_sns_publish" {
  statement {
    actions = ["sns:Publish"]
    effect  = "Allow"
    resources = [
      aws_sns_topic.dap_s3_upload_notifications.arn
    ]
  }
}
