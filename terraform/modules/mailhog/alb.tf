# Public ALB
# tfsec:ignore:aws-elb-alb-not-public
resource "aws_lb" "main" {
  name                       = "mailhog-public-alb-${var.environment}"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  preserve_host_header       = true
}

resource "aws_security_group" "alb" {
  vpc_id      = var.vpc.id
  description = "MailHog ALB ${var.environment}"
  name        = "mailhog-public-alb-sg-${var.environment}"
}

resource "aws_security_group_rule" "alb_egress" {
  security_group_id = aws_security_group.alb.id
  type              = "egress"
  description       = "HTTP egress to MailHog"
  from_port         = 8025
  to_port           = 8025
  protocol          = "tcp"
  cidr_blocks       = [var.private_subnet.cidr_block]
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

resource "aws_acm_certificate" "alb" {
  domain_name       = "mail.${var.public_dns.base_domain}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.alb.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.public_dns.zone_id
}

resource "aws_acm_certificate_validation" "alb" {
  certificate_arn         = aws_acm_certificate.alb.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}

resource "aws_route53_record" "public" {
  zone_id = var.public_dns.zone_id
  name    = "mail.${var.public_dns.base_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = false
  }
}

resource "aws_alb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2019-08"
  certificate_arn   = aws_acm_certificate_validation.alb.certificate_arn
  depends_on        = [aws_lb_target_group.main]

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_lb_target_group" "main" {
  name_prefix = "mail"
  port        = 8025
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.main.id
  port             = 8025
}
