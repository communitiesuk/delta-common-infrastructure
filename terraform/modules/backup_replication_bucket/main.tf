variable "environment" {
  type = string
}

variable "s3_access_log_expiration_days" {
  type = number
}

variable "compliance_retention_days" {
  type        = number
  description = "Default compliance retention period for objects in this bucket, during which the object version cannot be deleted."
}

variable "object_expiration_days" {
  type        = number
  description = "Expire objects after this many days. They will then become noncurrent and eventually be permanently deleted."
}

output "bucket" {
  value = {
    arn  = module.bucket.bucket_arn
    name = module.bucket.bucket
  }
}

# S3 bucket with Object Lock enabled for replicating backups into
module "bucket" {
  source = "../s3_bucket"

  bucket_name                        = "dluhc-backup-locked-${var.environment}"
  access_log_bucket_name             = "dluhc-backup-locked-access-logs-${var.environment}"
  noncurrent_version_expiration_days = null # Specify our own lifecycle policy
  access_s3_log_expiration_days      = var.s3_access_log_expiration_days

  object_lock_enabled = true
}

resource "aws_s3_bucket_object_lock_configuration" "object_locked_backup_bucket" {
  bucket = module.bucket.bucket

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.compliance_retention_days
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "object_locked_backup_bucket" {
  bucket = module.bucket.bucket

  rule {
    id = "noncurrent-version-expiration"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = max(14, var.compliance_retention_days)
    }

    status = "Enabled"
  }

  rule {
    id = "expire"

    filter {
      prefix = ""
    }

    expiration {
      days = var.object_expiration_days
    }

    status = "Enabled"
  }
}
