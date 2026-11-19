# The dedicated log destination does not log to itself or retain deleted versions.
# tfsec:ignore:aws-s3-enable-bucket-logging tfsec:ignore:aws-s3-enable-versioning
resource "aws_s3_bucket" "runner_access_logs" {
  bucket = "${local.name}-dist-access-logs-${local.account_id}"
}

resource "aws_s3_bucket_public_access_block" "runner_access_logs" {
  bucket = aws_s3_bucket.runner_access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 server access log delivery uses SSE-S3 on the destination bucket.
# tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "runner_access_logs" {
  bucket = aws_s3_bucket.runner_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "runner_access_logs" {
  bucket = aws_s3_bucket.runner_access_logs.id

  rule {
    id     = "expire-old-access-logs"
    status = "Enabled"
    filter {}

    expiration {
      days = var.logging_retention_in_days
    }
  }
}

resource "aws_s3_bucket_policy" "runner_access_logs" {
  bucket = aws_s3_bucket.runner_access_logs.bucket
  policy = data.aws_iam_policy_document.runner_access_logs.json
}

data "aws_iam_policy_document" "runner_access_logs" {
  statement {
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.runner_access_logs.arn,
      "${aws_s3_bucket.runner_access_logs.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.runner_access_logs.arn}/access/*"]

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [module.runners.binaries_syncer.bucket.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}
