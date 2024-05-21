
# SNS topic for errors with EBS backups. Non-sensitive.
# tfsec:ignore:aws-sns-enable-topic-encryption
resource "aws_sns_topic" "ebs_backup_completed" {
  name = "ebs-backup-errors-${var.environment}"
}

data "aws_iam_policy_document" "ebs_backup_sns" {
  statement {
    actions = ["sns:Publish"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
    resources = [aws_sns_topic.ebs_backup_completed.arn]
  }
}

resource "aws_sns_topic_policy" "ebs_backup" {
  arn    = aws_sns_topic.ebs_backup_completed.arn
  policy = data.aws_iam_policy_document.ebs_backup_sns.json
}

resource "aws_sns_topic_subscription" "ebs_backup_errors" {
  for_each = toset(var.ebs_backup_error_notification_emails)

  topic_arn = aws_sns_topic.ebs_backup_completed.arn
  protocol  = "email"
  endpoint  = each.value

  filter_policy = jsonencode({
    State = [{ "anything-but" : "COMPLETED" }]
  })
}
