resource "aws_backup_vault" "system_drives" {
  name          = "system-drives-backup-vault-${var.environment}"
  force_destroy = true
}

resource "aws_backup_plan" "system_drives" {
  name = "system-drives-plan-${var.environment}"

  rule {
    rule_name         = "system-drives-backup-rule-${var.environment}"
    target_vault_name = aws_backup_vault.system_drives.name
    schedule          = var.system_drive_backup_schedule
    completion_window = 360

    lifecycle {
      delete_after = var.system_drive_backup_retention_days
    }
  }
}

resource "aws_backup_selection" "system_drives" {
  iam_role_arn = aws_iam_role.ebs_backup.arn
  name         = "system-drives-ebs"
  plan_id      = aws_backup_plan.system_drives.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "system-drive-backup"
    value = var.environment
  }
}
