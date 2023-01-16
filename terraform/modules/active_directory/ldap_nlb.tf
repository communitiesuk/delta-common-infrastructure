
resource "aws_lb" "ldap" {
  name               = "ldap-${var.environment}"
  internal           = true
  load_balancer_type = "network"
  subnets            = [for subnet in var.domain_controller_subnets : subnet.id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "ldap" {
  name_prefix        = "ldap-${substr(var.environment, 0, 1)}"
  port               = 389
  protocol           = "TCP"
  target_type        = "ip"
  vpc_id             = var.vpc.id
  preserve_client_ip = true

  stickiness {
    enabled = true
    type    = "source_ip"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group_attachment" "ldap" {
  for_each = aws_directory_service_directory.directory_service.dns_ip_addresses

  target_group_arn = aws_lb_target_group.ldap.arn
  port             = 389
  target_id        = each.value
}

resource "aws_lb_listener" "ldap" {
  load_balancer_arn = aws_lb.ldap.arn
  port              = 389
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ldap.arn
  }
}

resource "aws_route53_record" "ldap_internal_nlb" {
  zone_id = var.private_dns.zone_id
  name    = "ldap.${var.private_dns.base_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.ldap.dns_name
    zone_id                = aws_lb.ldap.zone_id
    evaluate_target_health = false
  }
}
