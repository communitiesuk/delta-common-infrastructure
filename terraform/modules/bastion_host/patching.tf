resource "aws_ssm_maintenance_window_target" "bastion" {
  count         = var.patch_maintenance_window == null ? 0 : 1
  window_id     = var.patch_maintenance_window.window_id
  name          = "${var.name_prefix}-bastion"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:Name"
    values = [local.instance_tags.Name]
  }
}

resource "aws_ssm_maintenance_window_task" "bastion_patch" {
  count           = var.patch_maintenance_window == null ? 0 : 1
  name            = "${var.name_prefix}-bastion-patch"
  window_id       = var.patch_maintenance_window.window_id
  max_concurrency = 1
  max_errors      = 0
  priority        = 1
  task_arn        = "AWS-RunShellScript"
  task_type       = "RUN_COMMAND"
  cutoff_behavior = "CONTINUE_TASK"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.bastion[0].id]
  }

  task_invocation_parameters {
    run_command_parameters {
      comment          = "Upgrade AL2023 and verify bastion SSH after patching"
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

      parameter {
        name   = "executionTimeout"
        values = ["3600"]
      }

      cloudwatch_config {
        cloudwatch_log_group_name = var.log_group_name
        cloudwatch_output_enabled = var.log_group_name != null
      }
    }
  }
}
