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

# Windows patch output is non-sensitive, but encrypt at rest with a CMK to satisfy IaC checks.
locals {
  windows_patch_log_group_name = "${var.environment}/windows-ssm-patch"
}

module "windows_patch_log_group" {
  source         = "../encrypted_log_groups"
  retention_days = var.patch_cloudwatch_log_expiration_days

  kms_key_alias_name = "windows-ssm-patch-logs-${var.environment}"
  log_group_names    = [local.windows_patch_log_group_name]
}

# CloudWatch Logs + metrics for SSM patch output.
# DescribeLogGroups and PutMetricData do not support resource-level permissions.
# PatchBaselineOperations "Posting metrics" calls PutMetricData; without it (or if
# the call hangs on a blocked endpoint) AWS-RunPatchBaseline never returns status to SSM.
# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "ad_management_patch_logs" {
  statement {
    actions = [
      "logs:DescribeLogGroups",
      "cloudwatch:PutMetricData",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    # SSM creates a new stream under this group for each command and instance.
    resources = [
      module.windows_patch_log_group.log_group_arns[0],
      "${module.windows_patch_log_group.log_group_arns[0]}:*",
    ]
  }
}

resource "aws_iam_policy" "ad_management_patch_logs" {
  name        = "ad-management-patch-logs-${var.environment}"
  description = "Allow Windows AD/CA patch instances to write SSM patch logs and Patch Manager metrics"
  policy      = data.aws_iam_policy_document.ad_management_patch_logs.json
}

resource "aws_iam_role_policy_attachment" "ad_management_patch_logs" {
  role       = aws_iam_role.ad_management_role.name
  policy_arn = aws_iam_policy.ad_management_patch_logs.arn
}

data "aws_iam_instance_profile" "ca_server" {
  count = var.include_ca ? 1 : 0
  name = element(
    split("/", data.aws_instance.ca_server[0].iam_instance_profile),
    length(split("/", data.aws_instance.ca_server[0].iam_instance_profile)) - 1,
  )
}

# Attach without updating the CA CloudFormation stack (stack updates force SG replacements).
resource "aws_iam_role_policy_attachment" "ca_server_patch_logs" {
  count      = var.include_ca ? 1 : 0
  role       = data.aws_iam_instance_profile.ca_server[0].role_name
  policy_arn = aws_iam_policy.ad_management_patch_logs.arn
}

resource "aws_ssm_maintenance_window_task" "ad_management_server_patch" {
  name            = "ad-management-server-patch-${var.environment}"
  window_id       = var.patch_maintenance_window.window_id
  max_concurrency = 1
  max_errors      = 0
  priority        = 1
  # AWS-RunPatchBaseline hangs InProgress after "Posting metrics" and never
  # returns status to SSM. AWS-InstallWindowsUpdates completes and reports Success.
  task_arn        = "AWS-InstallWindowsUpdates"
  task_type       = "RUN_COMMAND"
  cutoff_behavior = "CONTINUE_TASK"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.ad_management_server.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      comment         = "Install Windows updates on the Active Directory management server"
      timeout_seconds = 7200

      service_role_arn = var.patch_maintenance_window.service_role_arn
      notification_config {
        notification_arn    = var.patch_maintenance_window.errors_sns_topic_arn
        notification_events = ["TimedOut", "Cancelled", "Failed"]
        notification_type   = "Command"
      }

      parameter {
        name   = "Action"
        values = ["Install"]
      }

      parameter {
        name   = "AllowReboot"
        values = ["True"]
      }

      cloudwatch_config {
        cloudwatch_log_group_name = module.windows_patch_log_group.log_group_names[0]
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
  task_arn        = "AWS-InstallWindowsUpdates"
  task_type       = "RUN_COMMAND"
  cutoff_behavior = "CONTINUE_TASK"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.ca_server[0].id]
  }

  task_invocation_parameters {
    run_command_parameters {
      comment         = "Install Windows updates on the certificate authority server"
      timeout_seconds = 7200

      service_role_arn = var.patch_maintenance_window.service_role_arn
      notification_config {
        notification_arn    = var.patch_maintenance_window.errors_sns_topic_arn
        notification_events = ["TimedOut", "Cancelled", "Failed"]
        notification_type   = "Command"
      }

      parameter {
        name   = "Action"
        values = ["Install"]
      }

      parameter {
        name   = "AllowReboot"
        values = ["True"]
      }

      cloudwatch_config {
        cloudwatch_log_group_name = module.windows_patch_log_group.log_group_names[0]
        cloudwatch_output_enabled = true
      }
    }
  }
}
