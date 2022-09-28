# Treating access logs as non-sensitive
# tfsec:ignore:aws-s3-enable-bucket-encryption tfsec:ignore:aws-s3-encryption-customer-key tfsec:ignore:aws-s3-enable-bucket-logging tfsec:ignore:aws-s3-enable-versioning
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.prefix}jaspersoft-alb-access-logs"
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id = "expiration"

    filter {
      prefix = "${local.alb_log_prefix}/"
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
  alb_log_prefix = "${var.prefix}jaspersoft-alb"
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

# Public ALB
# tfsec:ignore:aws-elb-alb-not-public
resource "aws_lb" "main" {
  name                       = "${var.prefix}jaspersoft-alb"
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

  depends_on = [
    aws_s3_bucket_policy.allow_alb_logging
  ]
}

resource "aws_security_group" "alb" {
  vpc_id      = var.vpc_id
  description = "Jaspersoft ALB"
  name        = "${var.prefix}jaspersoft-alb-sg"
}

resource "aws_security_group_rule" "alb_egress" {
  type                     = "egress"
  description              = "HTTP to Jasper Server instance"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jaspersoft_server.id
  security_group_id        = aws_security_group.alb.id
}

# tfsec:ignore:aws-vpc-no-public-ingress-sgr
resource "aws_security_group_rule" "alb_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTP Ingress"
  security_group_id = aws_security_group.alb.id
}

# TODO: Set up a domain for this and use HTTPS
# tfsec:ignore:aws-elb-http-not-used
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_lb_target_group" "main" {
  name_prefix = "jspsft"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.jaspersoft_server.id
  port             = 8080
}
