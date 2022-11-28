resource "aws_kms_key" "ml_backup_bucket_key" {
  enable_key_rotation = true
  description         = "ml-backups-${var.environment}"
}

resource "aws_kms_alias" "ml_backup_bucket_key" {
  name          = "alias/ml-backups-${var.environment}"
  target_key_id = aws_kms_key.ml_backup_bucket_key.id
}

# TODO DT-129 Expire old backups
module "cpm_backup_bucket" {
  source = "../s3_bucket"

  bucket_name            = "dluhc-cpm-ml-backup-${var.environment}"
  access_log_bucket_name = "dluhc-cpm-ml-backup-access-logs-${var.environment}"
  force_destroy          = true # TODO DT-129 change
  kms_key_arn            = aws_kms_key.ml_backup_bucket_key.arn
}

# TODO DT-129 Expire old backups
module "delta_backup_bucket" {
  source = "../s3_bucket"

  bucket_name            = "dluhc-delta-ml-backup-${var.environment}"
  access_log_bucket_name = "dluhc-delta-ml-backup-access-logs-${var.environment}"
  force_destroy          = true # TODO DT-129 change
  kms_key_arn            = aws_kms_key.ml_backup_bucket_key.arn
}
