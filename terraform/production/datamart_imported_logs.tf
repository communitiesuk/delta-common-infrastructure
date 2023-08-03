# Logs imported from Datamart for retention

# At time of writing our policy is to retain production logs for two years,
# so this should be kept until March 2025, after which it can be deleted
module "datamart_imported_logs_bucket" {
  source = "../modules/s3_bucket"

  bucket_name                   = "dluhc-datamart-imported-logs-production"
  access_log_bucket_name        = "dluhc-datamart-imported-logs-production-access-logs"
  access_s3_log_expiration_days = local.s3_log_expiration_days
  policy                        = data.aws_iam_policy_document.allow_access_from_datamart.json
  restrict_public_buckets       = false
}

locals {
  datamart_account_id = "090682378586"
}

data "aws_iam_policy_document" "allow_access_from_datamart" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [local.datamart_account_id]
    }

    actions = [
      "s3:GetBucketLocation", "s3:GetEncryptionConfiguration", "s3:ListBucket", "s3:GetObject", "s3:DeleteObject"
    ]

    resources = [
      module.datamart_imported_logs_bucket.bucket_arn,
      "${module.datamart_imported_logs_bucket.bucket_arn}/*",
    ]
  }

  statement {
    principals {
      type        = "AWS"
      identifiers = [local.datamart_account_id]
    }

    actions = ["s3:PutObject"]

    resources = ["${module.datamart_imported_logs_bucket.bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      values   = ["GLACIER"] # "Glacier Flexible Retrieval"
      variable = "s3:x-amz-storage-class"
    }
  }
}
