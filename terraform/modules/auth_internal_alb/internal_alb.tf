resource "aws_lb" "main" {
  name                       = "${var.environment}-auth-internal-alb"
  internal                   = true
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.subnet_ids
  drop_invalid_header_fields = true
  preserve_host_header       = true
}

resource "aws_security_group" "alb" {
  vpc_id      = var.vpc.id
  description = "${var.environment} Auth internal ALB"
  name        = "${var.environment}-auth-internal-sg"
}

resource "aws_security_group_rule" "alb_egress_https" {
  security_group_id = aws_security_group.alb.id
  type              = "egress"
  description       = "HTTPS egress to VPC"
  from_port         = 8443
  to_port           = 8443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc.cidr_block]
}

resource "aws_security_group_rule" "alb_https_ingress" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc.cidr_block]
  description       = "HTTPS Ingress"
}

# The auth albs were shared by keycloak and the auth service so we defined the listener here and the rules in each repository
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2019-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Unknown route"
      status_code  = "404"
    }
  }
}
