
resource "aws_s3_bucket" "main" {
  bucket              = var.bucket_name
  force_destroy       = var.force_destroy
  object_lock_enabled = var.object_lock_enabled
}

resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id
  policy = data.aws_iam_policy_document.main.json
}

data "aws_iam_policy_document" "main" {

  source_policy_documents = var.policy == null ? [] : [var.policy]

  # Apply policy to enforce SSL connections.
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:*"
    ]

    effect = "Deny"

    resources = [
      aws_s3_bucket.main.arn,
      "${aws_s3_bucket.main.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
    }
  }
}

# Some buckets need to be shared across accounts which means no restrict_public_buckets
# tfsec:ignore:aws-s3-no-public-buckets
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = var.restrict_public_buckets
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.bucket

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count = var.noncurrent_version_expiration_days == null ? 0 : 1

  depends_on = [aws_s3_bucket_versioning.main]

  bucket = aws_s3_bucket.main.id

  rule {
    id = "expire-old-versions"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 14
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    expiration {
      expired_object_delete_marker = true
    }

    status = "Enabled"
  }
}

# Access logs bucket
# tfsec:ignore:aws-s3-enable-bucket-logging tfsec:ignore:aws-s3-enable-versioning
resource "aws_s3_bucket" "log_bucket" {
  bucket        = var.access_log_bucket_name
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_logging" "main" {
  bucket = aws_s3_bucket.main.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "log/"
}

# KMS encryption is not supported for logging target buckets
# tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id = "expire-old-logs"

    filter {
      prefix = ""
    }

    expiration {
      days = var.access_s3_log_expiration_days
    }

    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "allow_log_writes" {
  bucket = aws_s3_bucket.log_bucket.id
  policy = data.aws_iam_policy_document.allow_log_writes.json
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "allow_log_writes" {
  source_policy_documents = [data.aws_iam_policy_document.allow_ssl_requests_only.json]
  statement {
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.log_bucket.arn}/*"
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.main.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

# Apply policy to enforce SSL connections.
data "aws_iam_policy_document" "allow_ssl_requests_only" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:*"
    ]

    effect = "Deny"

    resources = [
      aws_s3_bucket.log_bucket.arn,
      "${aws_s3_bucket.log_bucket.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}
