provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

# Non sensitive
# tfsec:ignore:aws-sns-enable-topic-encryption
resource "aws_sns_topic" "alarm_sns_topic" {
  name         = "metric-alarms-${var.environment}"
  display_name = "Notifications for change in metric alarm status"
}

resource "aws_sns_topic_policy" "alarm_sns_topic_allow_s3_events" {
  arn    = aws_sns_topic.alarm_sns_topic.arn
  policy = data.aws_iam_policy_document.alarm_sns_topic_allow_s3_events.json
}

data "aws_iam_policy_document" "alarm_sns_topic_allow_s3_events" {
  statement {
    sid     = "allow-s3"
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    resources = [aws_sns_topic.alarm_sns_topic.arn]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid     = "allow-cloudwatch"
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    resources = [aws_sns_topic.alarm_sns_topic.arn]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_sms_preferences" "update_sms_prefs" {
  default_sender_id = "Delta"
}

resource "aws_sns_topic_subscription" "alarm_sns_topic" {
  for_each = toset(var.alarm_sns_topic_emails)

  topic_arn = aws_sns_topic.alarm_sns_topic.arn
  protocol  = "email"
  endpoint  = each.value
}

# Non sensitive
# tfsec:ignore:aws-sns-enable-topic-encryption
resource "aws_sns_topic" "alarm_sns_topic_global" {
  # Note that this topic is meant for "Global" services - by convention, these
  # services are located in us-east-1, so that's where we need to create the SNS
  # topic. Alarms cannot be connected cross-regionally so we need a duplicate topic
  # in the region that they will exist.
  provider     = aws.us-east-1
  name         = "metric-alarms-${var.environment}"
  display_name = "Notifications for change in metric alarm status"
}

resource "aws_sns_topic_subscription" "alarm_sns_topic_global" {
  provider = aws.us-east-1

  for_each = toset(var.alarm_sns_topic_emails)

  topic_arn = aws_sns_topic.alarm_sns_topic_global.arn
  protocol  = "email"
  endpoint  = each.value
}

# tfsec:ignore:aws-sns-enable-topic-encryption
resource "aws_sns_topic" "security_sns_topic" {
  name         = "security-alarms-${var.environment}"
  display_name = "Notifications for change in security status"
}

resource "aws_sns_topic_subscription" "security_sns_topic" {
  for_each = toset(var.security_sns_topic_emails)

  topic_arn = aws_sns_topic.security_sns_topic.arn
  protocol  = "email"
  endpoint  = each.value
}

# Non sensitive
# tfsec:ignore:aws-sns-enable-topic-encryption
resource "aws_sns_topic" "security_sns_topic_global" {
  # Note that this topic is meant for "Global" services - by convention, these
  # services are located in us-east-1, so that's where we need to create the SNS
  # topic. Alarms cannot be connected cross-regionally so we need a duplicate topic
  # in the region that they will exist.
  provider     = aws.us-east-1
  name         = "security-alarms-${var.environment}"
  display_name = "Notifications for change in security status"
}

resource "aws_sns_topic_subscription" "security_sns_topic_global" {
  provider = aws.us-east-1

  for_each = toset(var.security_sns_topic_emails)

  topic_arn = aws_sns_topic.security_sns_topic_global.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sns_topic_policy" "allow_guard_duty_events" {
  arn    = aws_sns_topic.security_sns_topic.arn
  policy = data.aws_iam_policy_document.allow_guard_duty_events.json
}

data "aws_iam_policy_document" "allow_guard_duty_events" {
  statement {
    sid     = "allow-guardduty"
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.security_sns_topic.arn]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid     = "allow-cloudwatch"
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    resources = [aws_sns_topic.security_sns_topic.arn]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}
