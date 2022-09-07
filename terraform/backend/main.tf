provider "aws" {
  region = "eu-west-1"
}

# TODO:tfsec Enable bucket encryption
# TODO:tfsec Consider enabling access logging
# tfsec:ignore:aws-s3-enable-bucket-encryption tfsec:ignore:aws-s3-encryption-customer-key tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "terraform_state" {
  bucket = "data-collection-service-tfstate-production"
  lifecycle {
    prevent_destroy = true
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