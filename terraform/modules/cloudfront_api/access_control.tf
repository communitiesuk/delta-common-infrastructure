resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.prefix}s3-control"
  description                       = "Access control for the s3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
