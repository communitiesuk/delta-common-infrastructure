provider "aws" {
  region = "eu-west-1"
  default_tags {
    tags = {
      project           = "Data Collection Service"
      business-unit     = "Digital Delivery"
      technical-contact = "Team-DLUHC@softwire.com"
      environment       = "production"
      repository        = "https://github.com/communitiesuk/delta-common-infrastructure"
      is-backend        = "true"
    }
  }
}

data "aws_region" "current" {}

resource "aws_kms_key" "state_bucket_encryption_key" {
  description         = "Terraform state bucket encryption key"
  enable_key_rotation = true
}

resource "aws_kms_alias" "state_bucket_encryption_key" {
  name          = "alias/terraform-state-encryption-production"
  target_key_id = aws_kms_key.state_bucket_encryption_key.key_id
}

module "state_bucket" {
  source                  = "../modules/s3_bucket"
  bucket_name             = "data-collection-service-tfstate-production"
  access_log_bucket_name  = "data-collection-service-tfstate-access-logs-production"
  kms_key_arn             = aws_kms_key.state_bucket_encryption_key.arn
  restrict_public_buckets = true
}

# Encryption/recovery not required - lock not sensitive
# tfsec:ignore:aws-dynamodb-enable-at-rest-encryption tfsec:ignore:aws-dynamodb-enable-recovery tfsec:ignore:aws-dynamodb-table-customer-key
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "tfstate-locks"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# Access to Terraform state, should be enough to do a refresh=false plan along with ReadOnlyAccess
# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "terraform_state_read_only" {
  statement {
    sid = "TFStateS3"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*",
    ]
  }

  statement {
    sid = "TFStateKMSKey"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [aws_kms_key.state_bucket_encryption_key.arn]
  }

  statement {
    sid = "TFStateLock"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [aws_dynamodb_table.terraform_state_lock.arn]
  }

  statement {
    sid = "ReadTFManagedSecrets"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      # Access secrets managed by Terraform
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:tf-*",
      # MarkLogic user and license secrets, value is read to pass to CloudFormation
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:ml-*",
    ]
  }
}

resource "aws_iam_policy" "terraform_state_read_only" {
  name   = "tf-state-read-only"
  policy = data.aws_iam_policy_document.terraform_state_read_only.json
}
