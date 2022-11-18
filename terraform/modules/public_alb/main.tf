# Public ALB
# tfsec:ignore:aws-elb-alb-not-public
resource "aws_lb" "main" {
  name                       = "${var.prefix}alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.subnet_ids
  drop_invalid_header_fields = true
  preserve_host_header       = true

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
  vpc_id      = var.vpc.id
  description = "${var.prefix} ALB"
  name        = "${var.prefix}alb-sg"
}

resource "aws_security_group_rule" "alb_egress" {
  security_group_id = aws_security_group.alb.id
  type              = "egress"
  description       = "HTTP egress to VPC"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [var.vpc.cidr_block]
}

# tfsec:ignore:aws-vpc-no-public-ingress-sgr
resource "aws_security_group_rule" "alb_https_ingress" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS Ingress"
}
