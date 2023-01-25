module "swagger_bucket" {
  source = "../s3_bucket"

  bucket_name            = "dluhc-delta-api-swagger-${var.environment}"
  access_log_bucket_name = "dluhc-delta-api-swagger-access-logs-${var.environment}"
  force_destroy          = true

  policy = data.aws_iam_policy_document.swagger_policy.json
}

data "aws_iam_policy_document" "swagger_policy" {
  statement {
    actions = ["s3:GetObject"]

    resources = ["${module.swagger_bucket.bucket_arn}/*"]

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
