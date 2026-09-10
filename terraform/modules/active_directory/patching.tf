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

  # Safe post-patch refresh so Settings "View update history" / USO stay closer to
  # installs done via AWS-InstallWindowsUpdates under NoAutoUpdate. Always exit 0.
  windows_wu_history_refresh_script = <<-EOT
    $ErrorActionPreference = 'Continue'
    Write-Output ("Computer=" + $env:COMPUTERNAME)
    Get-Process SystemSettings, ApplicationFrameHost -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    foreach ($s in @('bits', 'wuauserv', 'UsoSvc')) {
      try {
        Restart-Service -Name $s -Force -ErrorAction Stop
        Write-Output ("Restarted " + $s + " State=" + (Get-Service $s).Status)
      } catch {
        Start-Service -Name $s -ErrorAction SilentlyContinue
        Write-Output ("Start " + $s + " State=" + (Get-Service $s).Status + " err=" + $_.Exception.Message)
      }
    }
    $uso = Join-Path $env:SystemRoot 'System32\UsoClient.exe'
    if (Test-Path $uso) {
      & $uso StartScan 2>&1 | Out-Null
      Start-Sleep -Seconds 15
      & $uso StartInteractiveScan 2>&1 | Out-Null
      Write-Output 'UsoClient StartScan/StartInteractiveScan issued'
    } else {
      Write-Output 'UsoClient.exe not found'
    }
    try {
      $session = New-Object -ComObject Microsoft.Update.Session
      $searcher = $session.CreateUpdateSearcher()
      $result = $searcher.Search("IsInstalled=0 and Type='Software'")
      Write-Output ("AvailableUpdates=" + $result.Updates.Count)
      Write-Output ("HistoryCount=" + $searcher.GetTotalHistoryCount())
    } catch {
      Write-Output ("WUA search error: " + $_.Exception.Message)
    }
    Get-Service bits, wuauserv, UsoSvc | ForEach-Object { Write-Output ($_.Name + '=' + $_.Status) }
    exit 0
  EOT
}

module "windows_patch_log_group" {
  source         = "../encrypted_log_groups"
  retention_days = var.patch_cloudwatch_log_expiration_days

  kms_key_alias_name = "windows-ssm-patch-logs-${var.environment}"
  log_group_names    = [local.windows_patch_log_group_name]
}

# CloudWatch Logs permissions for SSM patch output.
# DescribeLogGroups does not support resource-level permissions (SSM agent calls it
# with an empty log-group ARN); other actions stay scoped to this log group.
# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "ad_management_patch_logs" {
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
    # SSM creates a new stream under this group for each command and instance.
    resources = [
      module.windows_patch_log_group.log_group_arns[0],
      "${module.windows_patch_log_group.log_group_arns[0]}:*",
    ]
  }
}

resource "aws_iam_policy" "ad_management_patch_logs" {
  name        = "ad-management-patch-logs-${var.environment}"
  description = "Allow Windows AD/CA patch instances to write SSM patch output"
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

resource "aws_ssm_maintenance_window_task" "ad_management_wu_history_refresh" {
  name            = "ad-management-wu-history-refresh-${var.environment}"
  window_id       = var.patch_maintenance_window.window_id
  max_concurrency = 1
  max_errors      = 0
  priority        = 3
  task_arn        = "AWS-RunPowerShellScript"
  task_type       = "RUN_COMMAND"
  cutoff_behavior = "CONTINUE_TASK"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.ad_management_server.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      comment         = "Refresh Windows Update / USO after AD patch so Settings history is less stale"
      timeout_seconds = 600

      service_role_arn = var.patch_maintenance_window.service_role_arn
      notification_config {
        notification_arn    = var.patch_maintenance_window.errors_sns_topic_arn
        notification_events = ["TimedOut", "Cancelled", "Failed"]
        notification_type   = "Command"
      }

      parameter {
        name   = "commands"
        values = [local.windows_wu_history_refresh_script]
      }

      cloudwatch_config {
        cloudwatch_log_group_name = module.windows_patch_log_group.log_group_names[0]
        cloudwatch_output_enabled = true
      }
    }
  }
}

resource "aws_ssm_maintenance_window_task" "ca_server_wu_history_refresh" {
  count           = var.include_ca ? 1 : 0
  name            = "ca-server-wu-history-refresh-${var.environment}"
  window_id       = var.patch_maintenance_window.window_id
  max_concurrency = 1
  max_errors      = 0
  priority        = 4
  task_arn        = "AWS-RunPowerShellScript"
  task_type       = "RUN_COMMAND"
  cutoff_behavior = "CONTINUE_TASK"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.ca_server[0].id]
  }

  task_invocation_parameters {
    run_command_parameters {
      comment         = "Refresh Windows Update / USO after CA patch so Settings history is less stale"
      timeout_seconds = 600

      service_role_arn = var.patch_maintenance_window.service_role_arn
      notification_config {
        notification_arn    = var.patch_maintenance_window.errors_sns_topic_arn
        notification_events = ["TimedOut", "Cancelled", "Failed"]
        notification_type   = "Command"
      }

      parameter {
        name   = "commands"
        values = [local.windows_wu_history_refresh_script]
      }

      cloudwatch_config {
        cloudwatch_log_group_name = module.windows_patch_log_group.log_group_names[0]
        cloudwatch_output_enabled = true
      }
    }
  }
}
