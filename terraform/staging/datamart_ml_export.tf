locals {
  datamart_account_id = "090682378586"
}

resource "aws_kms_key" "ml_backup_from_datamart_encryption" {
  enable_key_rotation = true
  description         = "ml-backup-datamart-encryption-staging"

  policy = data.aws_iam_policy_document.kms_ml_export_policy.json
}

module "datamart_ml_backups" {
  source = "../modules/s3_bucket"

  bucket_name            = "datamart-ml-backups-staging"
  access_log_bucket_name = "datamart-ml-backups-access-logs-staging"
  force_destroy          = true
  kms_key_arn            = aws_kms_key.ml_backup_from_datamart_encryption.arn
}

resource "aws_s3_bucket_policy" "datamart_ml_backups" {
  bucket = module.datamart_ml_backups.bucket
  policy = data.aws_iam_policy_document.allow_access_from_datamart.json
}

data "aws_iam_policy_document" "allow_access_from_datamart" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [local.datamart_account_id]
    }

    actions = [
      "s3:*",
    ]

    resources = [
      module.datamart_ml_backups.bucket_arn,
      "${module.datamart_ml_backups.bucket_arn}/*",
    ]
  }
}

data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "kms_ml_export_policy" {
  statement {
    sid       = "Enable IAM User Permissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "Allow access from Datamart"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [local.datamart_account_id]
    }
  }
}