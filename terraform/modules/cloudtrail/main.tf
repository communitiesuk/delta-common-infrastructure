# CloudTrail logging to S3 and CloudWatch

variable "environment" {
  type = string
}

variable "cloudwatch_log_expiration_days" {
  type = number
}

variable "s3_log_expiration_days" {
  type = number
}

variable "include_data_events_for_bucket_names" {
  type = list(string)
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  trail_name     = "dluhc-${var.environment}"
  log_group_name = "cloudtrail-${var.environment}"
  s3_prefix      = "dluhc-${var.environment}"
  data_event_s3_arns = [
    for name in concat(var.include_data_events_for_bucket_names) : "arn:aws:s3:::${name}/"
  ]
}

resource "aws_cloudtrail" "main" {
  name                          = local.trail_name
  s3_bucket_name                = module.s3_bucket.bucket
  s3_key_prefix                 = local.s3_prefix
  include_global_service_events = true
  kms_key_id                    = aws_kms_key.main.arn
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.main.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail.arn
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = local.data_event_s3_arns
    }
  }
}

resource "aws_kms_key" "main" {
  enable_key_rotation = true
  description         = "dluhc-delta-cloudtrail-${var.environment}"
  policy = templatefile("${path.module}/logging_kms_policy.json", {
    account_id      = data.aws_caller_identity.current.account_id
    region          = data.aws_region.current.name
    log_group_names = [local.log_group_name]
    trail_name      = local.trail_name
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/dluhc-delta-cloudtrail-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}

module "s3_bucket" {
  source = "../s3_bucket"

  access_log_bucket_name             = "dluhc-delta-cloudtrail-${var.environment}-access-logs"
  bucket_name                        = "dluhc-delta-cloudtrail-${var.environment}"
  access_s3_log_expiration_days      = var.s3_log_expiration_days
  policy                             = data.aws_iam_policy_document.bucket_policy.json
  kms_key_arn                        = aws_kms_key.main.arn
  noncurrent_version_expiration_days = null
}

resource "aws_s3_bucket_lifecycle_configuration" "expire" {
  bucket = module.s3_bucket.bucket

  rule {
    id = "expiration"
    filter {
      prefix = ""
    }
    expiration {
      days = var.s3_log_expiration_days
    }
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [module.s3_bucket.bucket_arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"
      ]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${module.s3_bucket.bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"
      ]
    }
  }
}

resource "aws_cloudwatch_log_group" "main" {
  name              = local.log_group_name
  retention_in_days = var.cloudwatch_log_expiration_days
  kms_key_id        = aws_kms_key.main.arn

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role" "cloudtrail" {
  name = "cloudtrail-to-cloudwatch-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "cloudtrail" {
  name   = "cloudtrail-to-cloudwatch-${var.environment}"
  role   = aws_iam_role.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_to_cloudwatch.json
}

# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "cloudtrail_to_cloudwatch" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.main.arn}:*"]
  }
}
