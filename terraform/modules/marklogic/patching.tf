resource "aws_ssm_maintenance_window_target" "ml_servers" {
  window_id     = var.patch_maintenance_window.window_id
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
  retention_in_days = var.cloudwatch_log_expiration_days
}

resource "aws_ssm_maintenance_window_task" "ml_patch" {
  name            = "marklogic-patch-${var.environment}"
  window_id       = var.patch_maintenance_window.window_id
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
      timeout_seconds = 1800

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
        cloudwatch_log_group_name = aws_cloudwatch_log_group.ml_patch.name
        cloudwatch_output_enabled = true
      }
    }
  }
}
