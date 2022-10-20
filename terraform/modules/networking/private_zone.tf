resource "aws_route53_zone" "private" {
  name    = var.private_dns_domain
  comment = "vpc-private-hosted-zone-${var.environment}"

  vpc {
    vpc_id = aws_vpc.vpc.id
  }
}
