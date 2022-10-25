data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  runner_log_files = [
    {
      "file_path" : "/var/log/messages",
      "log_group_name" : "messages",
      "log_stream_name" : "{instance_id}"
    },
    {
      "log_group_name" : "user_data",
      "file_path" : "/var/log/user-data.log",
      "log_stream_name" : "{instance_id}"
    },
    {
      "log_group_name" : "runner",
      "file_path" : "/opt/actions-runner/_diag/Runner_**.log",
      "log_stream_name" : "{instance_id}"
    },
    {
      "log_group_name" : "runner-startup",
      "file_path" : "/var/log/runner-startup.log",
      "log_stream_name" : "{instance_id}"
    }
  ]
  logfiles = [for l in local.runner_log_files : {
    "log_group_name" : "/github-self-hosted-runner/${var.environment}/${l.log_group_name}"
    "log_stream_name" : l.log_stream_name
    "file_path" : l.file_path
  }]

  loggroups_names = distinct([for l in local.logfiles : l.log_group_name])
}

resource "aws_ssm_parameter" "cloudwatch_agent_config_runner" {
  name = "${var.environment}-cloudwatch-agent-config-github-runner"
  type = "String"
  value = templatefile("${path.module}/templates/cloudwatch_config.json", {
    logfiles = jsonencode(local.logfiles)
  })
}

resource "aws_kms_key" "gh_log_groups" {
  enable_key_rotation = true
  description         = "Used by GitHub Runner logs - ${var.environment}"
  policy = templatefile("${path.module}/templates/logging_kms_policy.json", {
    account_id        = data.aws_caller_identity.current.account_id
    region            = data.aws_region.current.name
    log_group_pattern = "/github-self-hosted-runner/${var.environment}/*"
  })
}

resource "aws_cloudwatch_log_group" "gh_runners" {
  count             = length(local.loggroups_names)
  name              = local.loggroups_names[count.index]
  retention_in_days = 30
  kms_key_id        = aws_kms_key.gh_log_groups.arn
}

resource "aws_iam_role_policy" "cloudwatch" {
  name = "CloudWatchLoggingAndMetrics-${var.environment}"
  role = aws_iam_role.runner.name
  policy = templatefile("${path.module}/policies/instance_cloudwatch_policy.json",
    {
      ssm_parameter_arn = aws_ssm_parameter.cloudwatch_agent_config_runner.arn
    }
  )
}