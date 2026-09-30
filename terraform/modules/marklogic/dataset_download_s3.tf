# Temporary Data Store CSV downloads have a separate retention policy from DAP.
# Versioning would retain deleted download contents beyond the intended expiration window.
# This exception applies only to this disposable bucket.
# tfsec:ignore:aws-s3-enable-versioning
module "dataset_download_bucket" {
  source                             = "../s3_bucket"
  bucket_name                        = "dluhc-delta-dataset-download-${var.environment}"
  access_log_bucket_name             = "dluhc-delta-dataset-download-access-logs-${var.environment}"
  access_s3_log_expiration_days      = var.dap_export_s3_log_expiration_days
  noncurrent_version_expiration_days = null
  versioning_enabled                 = false
}

resource "aws_iam_role_policy_attachment" "ml_dataset_download_s3" {
  role       = aws_iam_role.ml_iam_role.name
  policy_arn = aws_iam_policy.ml_dataset_download_s3.arn
}

resource "aws_iam_policy" "ml_dataset_download_s3" {
  name        = "ml-instance-dataset-download-s3-${var.environment}"
  description = "Allows MarkLogic to generate and retrieve temporary Data Store CSV downloads"
  policy      = data.aws_iam_policy_document.ml_dataset_download_s3.json
}

data "aws_iam_policy_document" "ml_dataset_download_s3" {
  statement {
    actions = [
      "s3:GetBucketLocation",
      "s3:GetEncryptionConfiguration",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
    ]
    resources = [module.dataset_download_bucket.bucket_arn]
  }

  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetObject",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
    ]
    # Generated search ids and page names are only known at runtime.
    # Access is limited to the dedicated bucket's download prefix.
    # tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["${module.dataset_download_bucket.bucket_arn}/search/*"]
  }
}

# Expiration is calculated per object, rounded up to midnight UTC, and
# performed asynchronously by S3. A one-day rule is not an exact 24-hour TTL.
resource "aws_s3_bucket_lifecycle_configuration" "dataset_download" {
  depends_on = [module.dataset_download_bucket]
  bucket     = module.dataset_download_bucket.bucket

  rule {
    id     = "expire-temporary-downloads"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 1
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "remove-expired-delete-markers"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      expired_object_delete_marker = true
    }
  }
}
