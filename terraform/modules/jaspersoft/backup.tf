# AWS Backup set to backup the JasperSoft EC2 instance

data "aws_iam_policy_document" "aws_backup_assume_role" {
  statement {
    sid     = "AssumeServiceRole"
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "aws_backup_service_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

data "aws_iam_policy" "aws_restore_service_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

data "aws_caller_identity" "current_account" {}

// Required for restores
data "aws_iam_policy_document" "allow_iam_pass_role" {
  statement {
    sid       = "AllowPassRole"
    actions   = ["iam:PassRole"]
    effect    = "Allow"
    resources = ["arn:aws:iam::${data.aws_caller_identity.current_account.account_id}:role/*"]
  }
}

resource "aws_iam_role" "backup_service_role" {
  count              = var.enable_backup ? 1 : 0
  name               = "${var.prefix}AWSBackupServiceRole"
  description        = "Allows the AWS Backup Service to take scheduled backups"
  assume_role_policy = data.aws_iam_policy_document.aws_backup_assume_role.json
}

resource "aws_iam_role_policy" "backup_service_backup_policy" {
  count  = var.enable_backup ? 1 : 0
  policy = data.aws_iam_policy.aws_backup_service_policy.policy
  role   = aws_iam_role.backup_service_role[0].name

  lifecycle {
    # Temporarily ignored, the policy is too long "Maximum policy size of 10240 bytes exceeded"
    ignore_changes = [policy]
  }
}

resource "aws_iam_role_policy" "backup_service_restore_policy" {
  count  = var.enable_backup ? 1 : 0
  policy = data.aws_iam_policy.aws_restore_service_policy.policy
  role   = aws_iam_role.backup_service_role[0].name
}

resource "aws_iam_role_policy" "backup_service_pass_role_policy" {
  count  = var.enable_backup ? 1 : 0
  policy = data.aws_iam_policy_document.allow_iam_pass_role.json
  role   = aws_iam_role.backup_service_role[0].name
}

locals {
  backups = {
    schedule       = "cron(0 4 * * ? *)"
    retention_days = 30
  }
}

resource "aws_backup_vault" "jasperserver_backup" {
  count         = var.enable_backup ? 1 : 0
  name          = "${var.prefix}jaspersoft-backup-vault"
  force_destroy = true
}

resource "aws_backup_plan" "jasperserver_backup" {
  count = var.enable_backup ? 1 : 0
  name  = "${var.prefix}jaspersoft-backup-plan"

  rule {
    rule_name         = "${var.prefix}jaspersoft-backup-rule"
    target_vault_name = aws_backup_vault.jasperserver_backup[0].name
    schedule          = local.backups.schedule
    completion_window = 300

    lifecycle {
      delete_after = local.backups.retention_days
    }
  }
}

resource "aws_backup_selection" "jasperserver_backup" {
  count        = var.enable_backup ? 1 : 0
  iam_role_arn = aws_iam_role.backup_service_role[0].arn
  name         = "${var.prefix}jaspersoft-instance"
  plan_id      = aws_backup_plan.jasperserver_backup[0].id

  resources = [
    aws_instance.jaspersoft_server.arn
  ]
}
