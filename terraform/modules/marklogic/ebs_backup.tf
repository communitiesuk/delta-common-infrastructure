locals {
  ebs_backups = {
    schedule       = "cron(0 22 * * ? *)"
    retention_days = 7
  }
}

resource "aws_backup_vault" "ebs" {
  name          = "marklogic-backup-vault-${var.environment}"
  force_destroy = false
}

resource "aws_backup_plan" "ebs" {
  name = "marklogic-backup-plan-${var.environment}"

  rule {
    rule_name         = "marklogic-backup-rule-${var.environment}"
    target_vault_name = aws_backup_vault.ebs.name
    schedule          = local.ebs_backups.schedule
    completion_window = 600 # Minutes

    lifecycle {
      delete_after = local.ebs_backups.retention_days
    }
  }
}

resource "aws_backup_selection" "ebs" {
  iam_role_arn = var.ebs_backup_role_arn
  name         = "marklogic-ebs-volumes-${var.environment}"
  plan_id      = aws_backup_plan.ebs.id

  resources = [for volume in aws_ebs_volume.marklogic_data_volumes : volume.arn]
}

resource "aws_backup_vault_notifications" "ebs_backup_completed" {
  backup_vault_name   = aws_backup_vault.ebs.name
  sns_topic_arn       = var.ebs_backup_completed_sns_topic_arn
  backup_vault_events = ["BACKUP_JOB_COMPLETED"]
}
