resource "aws_ssm_maintenance_window" "ml_patch" {
  name              = "marklogic-patch-${var.environment}"
  schedule          = "cron(00 06 ? * ${var.patch_day} *)"
  schedule_timezone = "Etc/UTC"
  duration          = 2
  cutoff            = 1
}

resource "aws_ssm_maintenance_window_target" "ml_servers" {
  window_id     = aws_ssm_maintenance_window.ml_patch.id
  name          = "marklogic-${var.environment}"
  description   = "MarkLogic servers from the ${var.environment} environment"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:marklogic:stack:name"
    values = [local.stack_name]
  }
}

# Yum update output, non-sensitive
# tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "ml_patch" {
  name              = "${var.environment}/marklogic-ssm-patch"
  retention_in_days = 60
}

resource "aws_ssm_maintenance_window_task" "ml_patch" {
  name            = "marklogic-patch-${var.environment}"
  window_id       = aws_ssm_maintenance_window.ml_patch.id
  max_concurrency = 1
  max_errors      = 0
  priority        = 1
  task_arn        = "AWS-RunShellScript"
  task_type       = "RUN_COMMAND"
  cutoff_behavior = "CONTINUE_TASK"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.ml_servers.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      comment         = "Yum update security"
      timeout_seconds = 900

      service_role_arn = aws_iam_role.ml_patch_sns_publish.arn
      notification_config {
        notification_arn    = aws_sns_topic.ml_patch_notifications.arn
        notification_events = ["TimedOut", "Cancelled", "Failed"]
        notification_type   = "Command"
      }

      parameter {
        name   = "commands"
        values = ["yum update --security -y"]
      }

      cloudwatch_config {
        cloudwatch_log_group_name = aws_cloudwatch_log_group.ml_patch.name
        cloudwatch_output_enabled = true
      }
    }
  }
}

# SNS topic for errors with the maintenance window job. Non-sensitive.
# tfsec:ignore:aws-sns-enable-topic-encryption
resource "aws_sns_topic" "ml_patch_notifications" {
  name = "marklogic-patch-errors-${var.environment}"
}

# TODO DT-49: Add subscription

resource "aws_iam_role" "ml_patch_sns_publish" {
  name = "marklogic-patch-sns-publish-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ml_patch_sns_publish" {
  role       = aws_iam_role.ml_patch_sns_publish.name
  policy_arn = aws_iam_policy.ml_patch_sns_publish.arn
}

resource "aws_iam_policy" "ml_patch_sns_publish" {
  name        = "marklogic-patch-sns-publish-${var.environment}"
  description = "Used by SSM to push notifications when MarkLogic os updates fail to apply"

  policy = data.aws_iam_policy_document.ml_patch_sns_publish.json
}

data "aws_iam_policy_document" "ml_patch_sns_publish" {
  statement {
    actions = ["sns:Publish"]
    effect  = "Allow"
    resources = [
      aws_sns_topic.ml_patch_notifications.arn
    ]
  }
}
