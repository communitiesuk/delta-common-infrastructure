# Treating access logs as non-sensitive
# tfsec:ignore:aws-s3-enable-bucket-encryption tfsec:ignore:aws-s3-encryption-customer-key tfsec:ignore:aws-s3-enable-bucket-logging tfsec:ignore:aws-s3-enable-versioning
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.prefix}alb-access-logs-${var.environment}"
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id = "expiration"

    filter {
      prefix = "${local.access_log_prefix}/"
    }

    expiration {
      days = var.alb_log_expiration_days
    }

    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

locals {
  alb_log_prefix = "${var.prefix}alb-${var.environment}"
}

data "aws_elb_service_account" "main" {}
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "allow_alb_logging" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = <<POLICY
{
  "Id": "Allow logging from ALB",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.alb_logs.arn}/${local.alb_log_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
      "Principal": {
        "AWS": [
          "${data.aws_elb_service_account.main.arn}"
        ]
      }
    }
  ]
}
POLICY
}

# Public ALB. Only accepts connections from CloudFront, enforced by header.
# tfsec:ignore:aws-elb-alb-not-public
resource "aws_lb" "main" {
  name                       = "${var.prefix}alb-${var.environment}"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [for subnet in var.public_alb_subnets : subnet.id]
  drop_invalid_header_fields = true

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = local.alb_log_prefix
    enabled = true
  }

  tags = {
    Environment = var.environment
  }

  depends_on = [
    aws_s3_bucket_policy.allow_alb_logging
  ]
}

# Allow public ingress, access enforced with header
# tfsec:ignore:aws-vpc-no-public-ingress-sgr
resource "aws_security_group" "alb" {
  vpc_id      = var.vpc.id
  description = "Public ALB"
  name        = "${var.prefix}alb-sg-${var.environment}"

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.nginx_test_subnet.cidr_block]
    description = "HTTP to nginx box"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP Ingress"
  }
}

# TODO: Set up a domain for this and use HTTPS
# tfsec:ignore:aws-elb-http-not-used
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Incorrect CloudFront key"
      status_code  = "400"
    }
  }
}

resource "aws_lb_listener_rule" "static" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    http_header {
      http_header_name = local.cloudfront_key_header
      values           = [random_password.cloudfront_alb_key.result]
    }
  }
}

resource "aws_lb_target_group" "main" {
  name        = "${var.prefix}alb-tg-${var.environment}"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc.id
}

resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.nginx_server.id
  port             = 80
}
