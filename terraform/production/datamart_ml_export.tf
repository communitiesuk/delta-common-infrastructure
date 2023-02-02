locals {
  datamart_account_id = "090682378586"
}

module "datamart_ml_backups" {
  source = "../modules/s3_bucket"

  bucket_name                   = "datamart-ml-backups-production"
  access_log_bucket_name        = "datamart-ml-backups-access-logs-production"
  force_destroy                 = true
  restrict_public_buckets       = false
  policy                        = data.aws_iam_policy_document.allow_access_from_datamart.json
  access_s3_log_expiration_days = local.s3_log_expiration_days
}

data "aws_iam_policy_document" "allow_access_from_datamart" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [local.datamart_account_id]
    }

    actions = [
      "s3:GetEncryptionConfiguration", "s3:GetObject", "s3:GetBucketLocation", "s3:ListBucket", "s3:PutObject", "s3:DeleteObject",
      "s3:AbortMultipartUpload", "s3:ListBucketMultipartUploads", "s3:ListMultipartUploadParts",
    ]

    resources = [
      module.datamart_ml_backups.bucket_arn,
      "${module.datamart_ml_backups.bucket_arn}/*",
    ]
  }
}

data "aws_caller_identity" "current" {}

output "datamart_ml_backup_bucket" {
  value = module.datamart_ml_backups.bucket_arn
}

resource "aws_iam_role_policy_attachment" "datamart_backups_read" {
  role       = module.marklogic.instance_iam_role
  policy_arn = aws_iam_policy.datamart_backups_read.arn
}

resource "aws_iam_policy" "datamart_backups_read" {
  name        = "ml-instance-datamart-export-s3-read-production"
  description = "Allows MarkLogic instances to read the exported backups from datamart"

  policy = data.aws_iam_policy_document.datamart_backups_read.json
}

#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "datamart_backups_read" {
  statement {
    actions = ["s3:GetObject", "s3:GetBucketLocation", "s3:GetEncryptionConfiguration", "s3:ListBucket"]
    effect  = "Allow"
    resources = [
      module.datamart_ml_backups.bucket_arn,
      "${module.datamart_ml_backups.bucket_arn}/*",
    ]
  }
}
