locals {
  s151_export_path                          = "/delta/s151/export"
  latest_s151_export_files_lifespan_in_days = 7
  s151_bucket_name                          = "dluhc-delta-s151-export-${var.environment}"
  s151_bucket_arn                           = "arn:aws:s3:::${local.s151_bucket_name}"
}

module "s151_export_bucket" {
  source                             = "../s3_bucket"
  bucket_name                        = local.s151_bucket_name
  access_log_bucket_name             = "dluhc-delta-s151-export-access-logs-${var.environment}"
  access_s3_log_expiration_days      = var.s151_export_s3_log_expiration_days
  noncurrent_version_expiration_days = null
  policy                             = length(var.s151_external_canonical_users) == 0 ? "" : data.aws_iam_policy_document.allow_access_s151_bucket.json
}

data "aws_iam_policy_document" "allow_access_s151_bucket" {
  statement {
    principals {
      type        = "AWS"
      identifiers = var.s151_external_role_arns
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketLocation"
    ]

    resources = [
      local.s151_bucket_arn,
      "${local.s151_bucket_arn}/latest/*",
    ]
  }
  dynamic "statement" {
    for_each = length(var.s151_external_canonical_users) > 1 ? [1] : []
    content {
      sid    = "AllowExternalBucketAccess"
      effect = "Allow"
      principals {
        type        = "CanonicalUser"
        identifiers = var.s151_external_canonical_users
      }
      actions = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      resources = [
        local.s151_bucket_arn,
        "${local.s151_bucket_arn}/latest/*",
      ]
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "s151_export" {
  depends_on = [module.s151_export_bucket]

  bucket = module.s151_export_bucket.bucket

  rule {
    id = "expire-old-versions"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = local.latest_s151_export_files_lifespan_in_days
    }

    status = "Enabled"
  }
}
