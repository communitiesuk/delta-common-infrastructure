module "error_bucket" {
  source = "../s3_bucket"

  bucket_name                   = "${var.prefix}error-page"
  access_log_bucket_name        = "${var.prefix}error-page-access-logs"
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

      values = [aws_cloudfront_distribution.main.arn]
    }
  }
}

resource "aws_s3_object" "error_page" {
  bucket       = module.error_bucket.bucket
  etag         = filemd5("${path.module}/error.html")
  key          = "static_errors/error.html"
  source       = "${path.module}/error.html"
  content_type = "text/html"
}

resource "aws_s3_object" "unavailable_page" {
  bucket       = module.error_bucket.bucket
  etag         = filemd5("${path.module}/503.html")
  key          = "static_errors/503.html"
  source       = "${path.module}/503.html"
  content_type = "text/html"
}
