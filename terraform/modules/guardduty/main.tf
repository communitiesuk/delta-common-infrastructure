variable "notification_email" {
  type    = string
  default = null
}

resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = false
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }
}

resource "aws_cloudwatch_event_rule" "console" {
  name        = "capture-guardduty-findings"
  description = "Capture any AWS GuardDuty findings of medium-high severity"

  event_pattern = <<EOF
{
  "source": [
    "aws.guardduty"
  ],  
  "detail-type": [
    "GuardDuty Finding"
  ],
  "detail": {
    "severity": [
      4,4.0,4.1,4.2,4.3,4.4,4.5,4.6,4.7,4.8,4.9,
      5,5.0,5.1,5.2,5.3,5.4,5.5,5.6,5.7,5.8,5.9,
      6,6.0,6.1,6.2,6.3,6.4,6.5,6.6,6.7,6.8,6.9,
      7,7.0,7.1,7.2,7.3,7.4,7.5,7.6,7.7,7.8,7.9,
      8,8.0,8.1,8.2,8.3,8.4,8.5,8.6,8.7,8.8,8.9
    ]
  }
}
EOF
}

resource "aws_sns_topic" "guardduty_events" {
  name = "aws-guardduty-events"
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.console.name
  target_id = "SendToGuarddutySNS"
  arn       = aws_sns_topic.guardduty_events.arn
}

resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.guardduty_events.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.guardduty_events.arn]
  }
}

resource "aws_sns_topic_subscription" "user_updates_sqs_target" {
  count     = var.notification_email == null ? 0 : 1
  topic_arn = aws_sns_topic.guardduty_events.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
