provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

resource "aws_acm_certificate_validation" "cloudfront_domains" {
  provider = aws.us-east-1

  certificate_arn = var.cloudfront_domain.acm_certificate_arn
}
