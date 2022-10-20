provider "aws" {
  region = "eu-west-1"
  default_tags {
    tags = {
      project           = "Data Collection Service"
      business-unit     = "Digital Delivery"
      technical-contact = "Team-DLUHC@softwire.com"
      environment       = "staging"
      repository        = "https://github.com/communitiesuk/delta-common-infrastructure"
      is-backend        = "true"
    }
  }
}

resource "aws_kms_key" "state_bucket_encryption_key" {
  description         = "Terraform state bucket encryption key"
  enable_key_rotation = true
}

resource "aws_s3_bucket_logging" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.state_access_log_bucket.id
  target_prefix = "production/"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "data-collection-service-tfstate-dev"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.state_bucket_encryption_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
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
