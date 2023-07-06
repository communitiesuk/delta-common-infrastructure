# We split horizon the DNS for auth.delta.<domain> so that requests from within the VPC
# go straight to the internal ALB
resource "aws_route53_zone" "auth_split_horizon" {
  name    = var.auth_domain
  comment = "vpc-auth-split-horizon-zone-${var.environment}"

  vpc {
    vpc_id = var.vpc.id
  }
}

resource "aws_route53_record" "auth_split_horizon" {
  zone_id = aws_route53_zone.auth_split_horizon.zone_id
  name    = var.auth_domain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = false
  }
}
