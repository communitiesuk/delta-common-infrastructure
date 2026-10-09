resource "aws_ssm_maintenance_window_target" "gh_runner" {
  window_id     = var.patch_maintenance_window.window_id
  name          = "github-runner-${var.environment}"
  description   = "GitHub Actions runner from the ${var.environment} environment"
  resource_type = "INSTANCE"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.gh_runner.id]
  }
}

# Named under the existing runner log prefix so aws_kms_key.gh_log_groups covers it.
resource "aws_cloudwatch_log_group" "gh_runner_patch" {
  name              = "/github-self-hosted-runner/${var.environment}/ssm-patch"
  retention_in_days = var.patch_cloudwatch_log_expiration_days
  kms_key_id        = aws_kms_key.gh_log_groups.arn
}

resource "aws_ssm_maintenance_window_task" "gh_runner_patch" {
  name            = "github-runner-patch-${var.environment}"
  window_id       = var.patch_maintenance_window.window_id
  max_concurrency = 1
  max_errors      = 0
  priority        = 1
  task_arn        = "AWS-RunShellScript"
  task_type       = "RUN_COMMAND"
  cutoff_behavior = "CONTINUE_TASK"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.gh_runner.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      comment         = "AL2023 release upgrade / security updates"
      timeout_seconds = 3600

      service_role_arn = var.patch_maintenance_window.service_role_arn
      notification_config {
        notification_arn    = var.patch_maintenance_window.errors_sns_topic_arn
        notification_events = ["TimedOut", "Cancelled", "Failed"]
        notification_type   = "Command"
      }

      parameter {
        name   = "commands"
        values = [file("${path.module}/scripts/patch.sh")]
      }

      cloudwatch_config {
        cloudwatch_log_group_name = aws_cloudwatch_log_group.gh_runner_patch.name
        cloudwatch_output_enabled = true
      }
    }
  }
}
