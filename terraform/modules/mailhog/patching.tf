resource "aws_ssm_maintenance_window_target" "mailhog" {
  window_id     = var.patch_maintenance_window.window_id
  name          = "mailhog-${var.environment}"
  description   = "MailHog server from the ${var.environment} environment"
  resource_type = "INSTANCE"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.main.id]
  }
}

module "patch_log_group" {
  source = "../encrypted_log_groups"

  kms_key_alias_name = "mailhog-ssm-patch-logs-${var.environment}"
  log_group_names    = ["${var.environment}/mailhog-ssm-patch"]
  retention_days     = var.patch_cloudwatch_log_expiration_days
}

# DescribeLogGroups does not support resource-level permissions.
# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "patch_logs" {
  statement {
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = [
      module.patch_log_group.log_group_arns[0],
      "${module.patch_log_group.log_group_arns[0]}:*",
    ]
  }
}

resource "aws_iam_role_policy" "patch_logs" {
  name   = "mailhog-patch-logs-${var.environment}"
  role   = aws_iam_role.main.name
  policy = data.aws_iam_policy_document.patch_logs.json
}

resource "aws_ssm_maintenance_window_task" "mailhog_patch" {
  name            = "mailhog-patch-${var.environment}"
  window_id       = var.patch_maintenance_window.window_id
  max_concurrency = 1
  max_errors      = 0
  priority        = 1
  task_arn        = "AWS-RunShellScript"
  task_type       = "RUN_COMMAND"
  cutoff_behavior = "CONTINUE_TASK"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.mailhog.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      comment          = "AL2023 release upgrade / security updates"
      timeout_seconds  = 3600
      service_role_arn = var.patch_maintenance_window.service_role_arn

      notification_config {
        notification_arn    = var.patch_maintenance_window.errors_sns_topic_arn
        notification_events = ["TimedOut", "Cancelled", "Failed"]
        notification_type   = "Command"
      }

      parameter {
        name   = "commands"
        values = [file("${path.module}/patch.sh")]
      }

      cloudwatch_config {
        cloudwatch_log_group_name = module.patch_log_group.log_group_names[0]
        cloudwatch_output_enabled = true
      }
    }
  }
}
