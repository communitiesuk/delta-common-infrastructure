provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

resource "aws_acm_certificate_validation" "cloudfront_domains" {
  count           = var.cloudfront_domain == null ? 0 : 1
  provider        = aws.us-east-1
  certificate_arn = var.cloudfront_domain.acm_certificate_arn
}
