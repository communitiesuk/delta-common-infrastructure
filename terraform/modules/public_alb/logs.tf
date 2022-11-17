# Access logs bucket
# tfsec:ignore:aws-s3-enable-bucket-logging tfsec:ignore:aws-s3-enable-versioning
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.prefix}alb-access-logs"
  force_destroy = true
}

# Application Load Balancer access logs do not support using a customer-managed KMS key
# tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id = "expiration"

    filter {
      prefix = "${local.alb_log_prefix}/"
    }

    expiration {
      days = var.log_expiration_days
    }

    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

locals {
  alb_log_prefix = "${var.prefix}alb"
}

data "aws_elb_service_account" "main" {}
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "allow_alb_logging" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = <<POLICY
{
  "Id": "Allow logging from ALB",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.alb_logs.arn}/${local.alb_log_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
      "Principal": {
        "AWS": [
          "${data.aws_elb_service_account.main.arn}"
        ]
      }
    }
  ]
}
POLICY
}
