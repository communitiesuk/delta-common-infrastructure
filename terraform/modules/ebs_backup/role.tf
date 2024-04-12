data "aws_iam_policy_document" "backup_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
  version = "2012-10-17"
}

resource "aws_iam_role" "ebs_backup" {
  name               = "aws-backup-service-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role.json
}

data "aws_iam_policy" "service_backup" {
  name = "AWSBackupServiceRolePolicyForBackup"
}

data "aws_iam_policy" "service_restore" {
  name = "AWSBackupServiceRolePolicyForRestores"
}

resource "aws_iam_role_policy_attachment" "service_backup" {
  policy_arn = data.aws_iam_policy.service_backup.arn
  role       = aws_iam_role.ebs_backup.name
}

resource "aws_iam_role_policy_attachment" "service_restore" {
  policy_arn = data.aws_iam_policy.service_restore.arn
  role       = aws_iam_role.ebs_backup.name
}
