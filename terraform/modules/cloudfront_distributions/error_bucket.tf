module "error_bucket" {
  source = "../s3_bucket"

  bucket_name                   = "dluhc-error-page-${var.environment}"
  access_log_bucket_name        = "dluhc-error-page-access-logs-${var.environment}"
  force_destroy                 = true
  access_s3_log_expiration_days = var.swagger_s3_log_expiration_days # TODO DT-187 this isn't swagger (stage value is 60)

  policy = data.aws_iam_policy_document.error_bucket_policy.json
}

data "aws_iam_policy_document" "error_bucket_policy" {
  statement {
    actions = ["s3:GetObject"]

    resources = ["${module.error_bucket.bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
  }
}
