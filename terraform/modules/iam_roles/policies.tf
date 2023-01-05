data "aws_iam_policy" "cloudwatch_full_access" {
  arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

data "aws_iam_policy" "cloudwatch_read_only_access" {
  arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

# Permission to view the "automatic" dashboards CloudWatch makes for various services
# A limited version of ReadOnlyAccess for several services
data "aws_iam_policy" "cloudwatch_automatic_dashboards_access" {
  arn = "arn:aws:iam::aws:policy/CloudWatchAutomaticDashboardsAccess"
}

data "aws_iam_policy" "ssm_full_access" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

data "aws_iam_policy" "read_only_all" {
  arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# To be used with CloudWatchReadOnlyAccess
# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "cloudwatch_monitor" {
  statement {
    sid = "UpdateLogsInsightsQueries"
    actions = [
      "logs:PutQueryDefinition",
      "logs:DeleteQueryDefinition",
    ]
    resources = ["*"]
  }
  statement {
    sid = "UpdateDashboards"
    actions = [
      "cloudwatch:DeleteDashboards",
      "cloudwatch:PutDashboard",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cloudwatch_monitor" {
  name   = "cloudwatch-monitor-${var.environment}"
  policy = data.aws_iam_policy_document.cloudwatch_monitor.json
}

data "aws_iam_policy_document" "ssm_session_manager_basic" {
  statement {
    sid = "ReadInstancesAndSessions"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ssm:DescribeSessions",
      "ssm:GetConnectionStatus",
      "ssm:DescribeInstanceProperties",
      "ssm:GetCommandInvocation",
      "ssm:GetInventorySchema",
    ]
    resources = ["*"]
  }

  # tfsec:ignore:aws-iam-no-policy-wildcards
  statement {
    sid = "TerminateOwnSessions"
    actions = [
      "ssm:TerminateSession",
      "ssm:ResumeSession",
    ]
    resources = ["arn:aws:ssm:*:*:session/$${aws:username}-*"]
  }

  statement {
    sid = "PortForwardDocument"
    actions = [
      "ssm:StartSession"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}::document/AWS-StartPortForwardingSession",
    ]
  }
}

resource "aws_iam_policy" "ssm_session_manager_basic" {
  name   = "ssm-port-forward-basic-${var.environment}"
  policy = data.aws_iam_policy_document.ssm_session_manager_basic.json
}

data "aws_iam_policy_document" "ssm_marklogic" {
  statement {
    sid = "MLPortForwardInstance"
    actions = [
      "ssm:StartSession"
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*",
    ]
    condition {
      test     = "StringLike"
      variable = "ssm:resourceTag/Name"
      values   = ["MarkLogic-*"]
    }
    condition {
      test     = "StringLike"
      variable = "ssm:resourceTag/environment"
      values   = [var.environment]
    }
    condition {
      test     = "BoolIfExists"
      variable = "ssm:SessionDocumentAccessCheck"
      values   = ["true"]
    }
  }
}

resource "aws_iam_policy" "ssm_marklogic" {
  name   = "ssm-marklogic-${var.environment}"
  policy = data.aws_iam_policy_document.ssm_marklogic.json
}

data "aws_iam_policy_document" "ssm_adms_rdp" {
  statement {
    sid = "ADMSStartSession"
    actions = [
      "ssm:StartSession"
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*",
    ]
    condition {
      test     = "StringLike"
      variable = "ssm:resourceTag/Name"
      values   = ["ad-management-server-${var.environment}"]
    }
    condition {
      test     = "BoolIfExists"
      variable = "ssm:SessionDocumentAccessCheck"
      values   = ["true"]
    }
  }

  # These actions do not support resource restrictions
  # They allow creating graphical sessions to instances you can already call ssm:StartSession on
  # tfsec:ignore:aws-iam-no-policy-wildcards
  statement {
    sid = "GuiConnect"
    actions = [
      "ssm-guiconnect:CancelConnection",
      "ssm-guiconnect:GetConnection",
      "ssm-guiconnect:StartConnection"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ssm_adms_rdp" {
  name   = "ssm-adms-rdp-${var.environment}"
  policy = data.aws_iam_policy_document.ssm_adms_rdp.json
}