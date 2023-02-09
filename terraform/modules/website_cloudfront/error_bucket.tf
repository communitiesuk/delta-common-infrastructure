module "error_bucket" {
  source = "../s3_bucket"

  bucket_name                   = "dluhc-error-page-${var.environment}"
  access_log_bucket_name        = "dluhc-error-page-access-logs-${var.environment}"
  force_destroy                 = true
  access_s3_log_expiration_days = 60

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

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"

      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

resource "aws_s3_object" "error_page" {
  bucket = module.error_bucket.bucket_name
  key    = "error-page"
  source = "./error.html"
}
