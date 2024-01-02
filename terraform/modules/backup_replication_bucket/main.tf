variable "environment" {
  type = string
}

variable "s3_access_log_expiration_days" {
  type = number
}

variable "compliance_retention_days" {
  type = number
}

variable "object_expiration_days" {
  type = number
}

output "bucket_arn" {
  value = module.bucket.bucket_arn
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

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    # There shouldn't be many noncurrent objects since the expiration rule will delete them directly,
    # so no harm in having this as a longer duration
    noncurrent_version_expiration {
      noncurrent_days = 180
    }

    status = "Enabled"
  }

  rule {
    id = "expire"

    filter {}

    expiration {
      days = var.object_expiration_days
    }

    status = "Enabled"
  }

  lifecycle {
    precondition {
      condition     = var.object_expiration_days > var.compliance_retention_days
      error_message = "The value for object_expiration_days must be larger than compliance_retention_days."
    }
  }
}
