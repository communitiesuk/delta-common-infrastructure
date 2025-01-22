# This is where the SSH keys of users will be stored
resource "aws_s3_bucket" "ssh_keys" {
  bucket_prefix = "${var.name_prefix}ssh-keys"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "ssh_keys_acl" {
  bucket = aws_s3_bucket.ssh_keys.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "ssh_keys_versioning" {
  bucket = aws_s3_bucket.ssh_keys.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "ssh_keys" {
  bucket = aws_s3_bucket.ssh_keys.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "ssh_keys" {
  bucket = aws_s3_bucket.ssh_keys.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "ssh_keys_readme" {
  bucket  = aws_s3_bucket.ssh_keys.id
  key     = "README.txt"
  content = "Drop public SSH keys of users who require access to the bastion. The filename (without the .pub and made all lowercase) will be their username."
}

# Another bucket for access logs for the keys bucket
# tfsec:ignore:aws-s3-enable-bucket-logging tfsec:ignore:aws-s3-enable-versioning
resource "aws_s3_bucket" "ssh_keys_logs" {
  bucket_prefix = "${var.name_prefix}ssh-keys-logs"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "ssh_keys_logs" {
  bucket = aws_s3_bucket.ssh_keys_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "ssh_keys_logs" {
  bucket = aws_s3_bucket.ssh_keys_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "allow_log_writes" {
  bucket = aws_s3_bucket.ssh_keys_logs.id
  policy = data.aws_iam_policy_document.allow_log_writes.json
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "allow_log_writes" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.ssh_keys_logs.arn}/*"
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.ssh_keys.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_logging" "ssh_keys" {
  bucket = aws_s3_bucket.ssh_keys.id

  target_bucket = aws_s3_bucket.ssh_keys_logs.id
  target_prefix = "${var.name_prefix}logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "ssh_keys_logs" {
  count = var.s3_access_log_expiration_days == null ? 0 : 1

  bucket = aws_s3_bucket.ssh_keys_logs.id

  rule {
    id = "expire-old-logs"

    filter {}

    expiration {
      days = var.s3_access_log_expiration_days
    }

    status = "Enabled"
  }
}
