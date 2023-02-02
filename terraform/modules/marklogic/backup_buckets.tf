resource "aws_kms_key" "ml_backup_bucket_key" {
  enable_key_rotation = true
  description         = "ml-backups-${var.environment}"
}

resource "aws_kms_alias" "ml_backup_bucket_key" {
  name          = "alias/ml-backups-${var.environment}"
  target_key_id = aws_kms_key.ml_backup_bucket_key.id
}

module "cpm_backup_bucket" {
  source = "../s3_bucket"

  bucket_name                        = "dluhc-cpm-ml-backup-${var.environment}"
  access_log_bucket_name             = "dluhc-cpm-ml-backup-access-logs-${var.environment}"
  kms_key_arn                        = aws_kms_key.ml_backup_bucket_key.arn
  noncurrent_version_expiration_days = 60
  access_s3_log_expiration_days      = var.backup_s3_log_expiration_days
}

module "delta_backup_bucket" {
  source = "../s3_bucket"

  bucket_name                        = "dluhc-delta-ml-backup-${var.environment}"
  access_log_bucket_name             = "dluhc-delta-ml-backup-access-logs-${var.environment}"
  kms_key_arn                        = aws_kms_key.ml_backup_bucket_key.arn
  noncurrent_version_expiration_days = 60
  access_s3_log_expiration_days      = var.backup_s3_log_expiration_days
}

# MarkLogic seems to need the "folders" to exist in S3
resource "aws_s3_object" "delta_content_folder" {
  bucket = module.delta_backup_bucket.bucket
  key    = "delta-content/"
}

resource "aws_s3_object" "security_folder" {
  bucket = module.delta_backup_bucket.bucket
  key    = "security/"
}

resource "aws_s3_object" "payments_content" {
  bucket = module.cpm_backup_bucket.bucket
  key    = "payments-content/"
}
