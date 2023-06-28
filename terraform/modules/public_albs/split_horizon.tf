# We split horizon the DNS for auth.delta.<domain> so that requests from within the VPC
# go straight to the ALB

data "aws_network_interface" "auth_alb_private_ips" {
  count = length(var.subnet_ids)

  filter {
    name   = "description"
    values = ["ELB ${module.auth_alb.arn_suffix}"]
  }
  filter {
    name   = "subnet-id"
    values = [var.subnet_ids[count.index]]
  }
}

resource "aws_route53_zone" "auth_split_horizon" {
  name    = var.auth_domain
  comment = "vpc-auth-split-horizon-zone-${var.environment}"

  vpc {
    vpc_id = var.vpc.id
  }
}

resource "aws_route53_record" "auth" {
  zone_id = aws_route53_zone.auth_split_horizon.zone_id
  name    = var.auth_domain
  type    = "A"
  ttl     = 30
  records = [for eni in data.aws_network_interface.auth_alb_private_ips : eni.private_ip]
}
