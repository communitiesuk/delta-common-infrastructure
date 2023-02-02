module "error_bucket" {
  source = "../s3_bucket"

  bucket_name            = "dluhc-error-page-${var.environment}"
  access_log_bucket_name = "dluhc-error-page-access-logs-${var.environment}"
  force_destroy          = true

  policy = data.aws_iam_policy_document.swagger_policy.json
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
