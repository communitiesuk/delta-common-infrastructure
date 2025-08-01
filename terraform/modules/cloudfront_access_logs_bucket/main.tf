variable "expiration_days" {
  type = number
}

variable "environment" {
  type = string
}

output "bucket_domain_name" {
  value = aws_s3_bucket.cloudfront_logs.bucket_domain_name
}

# Logs bucket
# tfsec:ignore:aws-s3-enable-bucket-logging tfsec:ignore:aws-s3-enable-versioning
resource "aws_s3_bucket" "cloudfront_logs" {
  bucket = "dluhc-cloudfront-access-logs-${var.environment}"
}

# tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    id = "default-to-intelligent-tiering"

    filter {
      prefix = ""
    }

    status = "Enabled"

    transition {
      storage_class = "INTELLIGENT_TIERING"
      days          = 0
    }
  }

  rule {
    id = "expiration"

    filter {
      prefix = ""
    }

    expiration {
      days = var.expiration_days
    }

    status = "Enabled"
  }
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.bucket
  name   = "EntireBucket"

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
  status = "Enabled"
}

resource "aws_s3_bucket_public_access_block" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_canonical_user_id" "current" {}
data "aws_cloudfront_log_delivery_canonical_user_id" "cloudfront_user" {}

resource "aws_s3_bucket_acl" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  access_control_policy {
    owner {
      id = data.aws_canonical_user_id.current.id
    }

    grant {
      grantee {
        id   = data.aws_canonical_user_id.current.id
        type = "CanonicalUser"
      }
      permission = "FULL_CONTROL"
    }

    grant {
      grantee {
        id   = data.aws_cloudfront_log_delivery_canonical_user_id.cloudfront_user.id
        type = "CanonicalUser"
      }
      permission = "FULL_CONTROL"
    }
  }
}
