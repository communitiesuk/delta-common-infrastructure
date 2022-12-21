resource "aws_ssm_maintenance_window_target" "jasper_server" {
  window_id     = var.patch_maintenance_window.window_id
  name          = "jasper-reports-server-${var.environment}"
  description   = "JasperReports server from the ${var.environment} environment"
  resource_type = "INSTANCE"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.jaspersoft_server.id]
  }
}

# Yum update output, non-sensitive
# tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "jasper_patch" {
  name              = "${var.environment}/jasper-ssm-patch"
  retention_in_days = 60
}

resource "aws_ssm_maintenance_window_task" "jasper_patch" {
  name            = "jasper-reports-server-patch-${var.environment}"
  window_id       = var.patch_maintenance_window.window_id
  max_concurrency = 1
  max_errors      = 0
  priority        = 1
  task_arn        = "AWS-RunShellScript"
  task_type       = "RUN_COMMAND"
  cutoff_behavior = "CONTINUE_TASK"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.jasper_server.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      comment         = "Apt update"
      timeout_seconds = 900

      service_role_arn = var.patch_maintenance_window.service_role_arn
      notification_config {
        notification_arn    = var.patch_maintenance_window.errors_sns_topic_arn
        notification_events = ["TimedOut", "Cancelled", "Failed"]
        notification_type   = "Command"
      }

      parameter {
        name   = "commands"
        values = ["apt-get update && apt-get upgrade -y"]
      }

      cloudwatch_config {
        cloudwatch_log_group_name = aws_cloudwatch_log_group.jasper_patch.name
        cloudwatch_output_enabled = true
      }
    }
  }
}
