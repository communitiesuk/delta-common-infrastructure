locals {
  trust_organisation_account_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          AWS = "arn:aws:iam::${var.organisation_account_id}:root"
        }
      }
    ]
  })
}

resource "aws_iam_role" "cloudwatch_monitor" {
  name                 = "assume-cloudwatch-monitor-${var.environment}"
  assume_role_policy   = local.trust_organisation_account_policy
  max_session_duration = 36000 # 10 hours
}

resource "aws_iam_role_policy_attachment" "cloudwatch_monitor" {
  for_each = {
    cloudwatch_monitor         = aws_iam_policy.cloudwatch_monitor.arn
    cloudwatch_auto_dashboards = data.aws_iam_policy.cloudwatch_automatic_dashboards_access.arn
  }

  role       = aws_iam_role.cloudwatch_monitor.name
  policy_arn = each.value
}

resource "aws_iam_role" "application_support" {
  name                 = "assume-application-support-${var.environment}"
  assume_role_policy   = local.trust_organisation_account_policy
  max_session_duration = 36000 # 10 hours
}

resource "aws_iam_role_policy_attachment" "application_support" {
  for_each = {
    cloudwatch_monitor         = aws_iam_policy.cloudwatch_monitor.arn
    cloudwatch_auto_dashboards = data.aws_iam_policy.cloudwatch_automatic_dashboards_access.arn
    ssm                        = aws_iam_policy.ssm_session_manager_basic.arn
    ssm_ml                     = aws_iam_policy.ssm_marklogic.arn
    ssm_ad                     = aws_iam_policy.ssm_adms_rdp.arn
  }

  role       = aws_iam_role.application_support.name
  policy_arn = each.value
}

resource "aws_iam_role" "infrastructure_support" {
  name                 = "assume-infra-support-${var.environment}"
  assume_role_policy   = local.trust_organisation_account_policy
  max_session_duration = 36000 # 10 hours
}

resource "aws_iam_role_policy_attachment" "infrastructure_support" {
  for_each = {
    read_only       = data.aws_iam_policy.read_only_all.arn
    cloudwatch_full = data.aws_iam_policy.cloudwatch_full_access.arn
    ssm_full        = data.aws_iam_policy.ssm_full_access.arn
    ssm_ad          = aws_iam_policy.ssm_adms_rdp.arn # Still need this for ssm-guiconnect actions
    aws_support     = data.aws_iam_policy.aws_support_access.arn
    tf_state        = data.aws_iam_policy.tf_state_read_only.arn
    cloudshell      = data.aws_iam_policy.cloudshell.arn
    infra_support   = aws_iam_policy.infra_support.arn
  }

  role       = aws_iam_role.infrastructure_support.name
  policy_arn = each.value
}
