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

locals {
  ebs_backups = {
    schedule       = "cron(0 2 * * ? *)"
    retention_days = 30
  }
}

resource "aws_backup_vault" "ebs" {
  name          = "marklogic-backup-vault-${var.environment}"
  force_destroy = true
}

resource "aws_backup_plan" "ebs" {
  name = "marklogic-backup-plan-${var.environment}"

  rule {
    rule_name         = "marklogic-backup-rule-${var.environment}"
    target_vault_name = aws_backup_vault.ebs.name
    schedule          = local.ebs_backups.schedule
    completion_window = 360

    lifecycle {
      delete_after = local.ebs_backups.retention_days
    }
  }
}

resource "aws_backup_selection" "ebs" {
  iam_role_arn = aws_iam_role.ebs_backup.arn
  name         = "marklogic-ebs-volumes-${var.environment}"
  plan_id      = aws_backup_plan.ebs.id

  resources = [for volume in aws_ebs_volume.marklogic_data_volumes : volume.arn]
}
