resource "aws_ssm_maintenance_window_target" "ad_management_server" {
  window_id     = var.patch_maintenance_window.window_id
  name          = "ad-management-server-${var.environment}"
  description   = "Active Directory management server from the ${var.environment} environment"
  resource_type = "INSTANCE"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.ad_management_server.id]
  }
}

resource "aws_ssm_maintenance_window_target" "ca_server" {
  count         = var.include_ca ? 1 : 0
  window_id     = var.patch_maintenance_window.window_id
  name          = "ca-server-${var.environment}"
  description   = "Certificate authority server from the ${var.environment} environment"
  resource_type = "INSTANCE"

  targets {
    key    = "InstanceIds"
    values = [data.aws_instance.ca_server[0].id]
  }
}

# Windows patch output is non-sensitive.
# tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "windows_patch" {
  name              = "${var.environment}/windows-ssm-patch"
  retention_in_days = var.patch_cloudwatch_log_expiration_days
}

data "aws_iam_policy_document" "ad_management_patch_logs" {
  statement {
    actions = ["logs:DescribeLogGroups"]
    # CloudWatch Logs does not support resource-level permissions for this action.
    # tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    # SSM creates a new stream under this group for each command and instance.
    # tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["${aws_cloudwatch_log_group.windows_patch.arn}:*"]
  }
}

resource "aws_iam_policy" "ad_management_patch_logs" {
  name        = "ad-management-patch-logs-${var.environment}"
  description = "Allow the Active Directory management server to write Windows patch output"
  policy      = data.aws_iam_policy_document.ad_management_patch_logs.json
}

resource "aws_iam_role_policy_attachment" "ad_management_patch_logs" {
  role       = aws_iam_role.ad_management_role.name
  policy_arn = aws_iam_policy.ad_management_patch_logs.arn
}

resource "aws_ssm_maintenance_window_task" "ad_management_server_patch" {
  name            = "ad-management-server-patch-${var.environment}"
  window_id       = var.patch_maintenance_window.window_id
  max_concurrency = 1
  max_errors      = 0
  priority        = 1
  task_arn        = "AWS-RunPatchBaseline"
  task_type       = "RUN_COMMAND"
  cutoff_behavior = "CONTINUE_TASK"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.ad_management_server.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      comment         = "Install approved Windows updates on the Active Directory management server"
      timeout_seconds = 7200

      service_role_arn = var.patch_maintenance_window.service_role_arn
      notification_config {
        notification_arn    = var.patch_maintenance_window.errors_sns_topic_arn
        notification_events = ["TimedOut", "Cancelled", "Failed"]
        notification_type   = "Command"
      }

      parameter {
        name   = "Operation"
        values = ["Install"]
      }

      parameter {
        name   = "RebootOption"
        values = ["RebootIfNeeded"]
      }

      parameter {
        name   = "StepTimeoutSeconds"
        values = ["7200"]
      }

      cloudwatch_config {
        cloudwatch_log_group_name = aws_cloudwatch_log_group.windows_patch.name
        cloudwatch_output_enabled = true
      }
    }
  }
}

resource "aws_ssm_maintenance_window_task" "ca_server_patch" {
  count           = var.include_ca ? 1 : 0
  name            = "ca-server-patch-${var.environment}"
  window_id       = var.patch_maintenance_window.window_id
  max_concurrency = 1
  max_errors      = 0
  priority        = 2
  task_arn        = "AWS-RunPatchBaseline"
  task_type       = "RUN_COMMAND"
  cutoff_behavior = "CONTINUE_TASK"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.ca_server[0].id]
  }

  task_invocation_parameters {
    run_command_parameters {
      comment         = "Install approved Windows updates on the certificate authority server"
      timeout_seconds = 7200

      service_role_arn = var.patch_maintenance_window.service_role_arn
      notification_config {
        notification_arn    = var.patch_maintenance_window.errors_sns_topic_arn
        notification_events = ["TimedOut", "Cancelled", "Failed"]
        notification_type   = "Command"
      }

      parameter {
        name   = "Operation"
        values = ["Install"]
      }

      parameter {
        name   = "RebootOption"
        values = ["RebootIfNeeded"]
      }

      parameter {
        name   = "StepTimeoutSeconds"
        values = ["7200"]
      }

      cloudwatch_config {
        cloudwatch_log_group_name = aws_cloudwatch_log_group.windows_patch.name
        cloudwatch_output_enabled = true
      }
    }
  }
}
