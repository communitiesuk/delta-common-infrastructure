# MarkLogic ignores the default KMS settings, so we no longer use this,
# but are keeping it for now just in case anything has ended up encrypted
resource "aws_kms_key" "ml_backup_bucket_key" {
  enable_key_rotation = true
  description         = "ml-backups-${var.environment}"
}

resource "aws_kms_alias" "ml_backup_bucket_key" {
  name          = "alias/ml-backups-${var.environment}"
  target_key_id = aws_kms_key.ml_backup_bucket_key.id
}

# MarkLogic itself manages deleting old daily backups
# We keep old versions for a few days in case of mistakes
module "daily_backup_bucket" {
  source = "../s3_bucket"

  bucket_name                        = "dluhc-daily-ml-backup-${var.environment}"
  access_log_bucket_name             = "dluhc-daily-backup-access-logs-${var.environment}"
  noncurrent_version_expiration_days = 3
  access_s3_log_expiration_days      = var.backup_s3_log_expiration_days
}

# We manage the weekly one with lifecycle rules
# Transitioning objects to Glacier IR then eventually expiring them
# This bucket is replicated to another bucket with Object Lock enabled
module "weekly_backup_bucket" {
  source = "../s3_bucket"

  bucket_name                        = "dluhc-weekly-ml-backup-${var.environment}"
  access_log_bucket_name             = "dluhc-weekly-ml-backup-access-logs-${var.environment}"
  noncurrent_version_expiration_days = null # Specify our own lifecycle policy
  access_s3_log_expiration_days      = var.backup_s3_log_expiration_days
}

locals {
  backup_directories = ["delta-content", "security", "payments-content", "delta-testing-centre-content"]
}

resource "aws_s3_bucket_lifecycle_configuration" "weekly_backup_bucket" {
  bucket = module.weekly_backup_bucket.bucket

  rule {
    id = "noncurrent-version-expiration"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 14
    }

    noncurrent_version_expiration {
      noncurrent_days = 20
    }

    status = "Enabled"
  }

  dynamic "rule" {
    for_each = toset(local.backup_directories)
    content {
      id = "expire-${rule.value}"

      filter {
        # MarkLogic starts its backup folder names with the date in a yyyyMMdd format
        # This lets us target those without deleting the folder markers we create below
        prefix = "${rule.value}/20"
      }

      # TODO DT-742 Remove transition and reduce expiration once we're confident in replication
      transition {
        days          = 7
        storage_class = "GLACIER_IR"
      }

      expiration {
        days = 80
      }

      status = "Enabled"
    }
  }
}

# MarkLogic seems to need the "folders" to exist in S3
# If you update these make sure to update the backups in delta-marklogic-deploy too
resource "aws_s3_object" "daily_folders" {
  for_each = toset(local.backup_directories)

  bucket = module.daily_backup_bucket.bucket
  key    = "${each.value}/"
}

resource "aws_s3_object" "weekly_folders" {
  for_each = toset(local.backup_directories)

  bucket = module.weekly_backup_bucket.bucket
  key    = "${each.value}/"
}
