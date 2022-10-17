resource "aws_vpc_dhcp_options" "dns_resolver" {
  domain_name_servers = var.dns_servers
  # TODO DT-58 is this intentional?
  domain_name = "eu-west-1.compute.internal"
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = aws_vpc.vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.dns_resolver.id
}

# resource "aws_security_group" "resolver_endpoint" {
#   name        = "resolver-endpoint-${var.environment}"
#   description = "Controls access to the VPC DNS resolver"
#   vpc_id      = aws_vpc.vpc.id

#   ingress {
#     description     = "Allow all ingress"
#     from_port       = 0
#     to_port         = 0
#     protocol        = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port = 0
#     to_port   = 0
#     protocol  = "-1"
#     # tfsec:ignore:aws-vpc-no-public-egress-sgr
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "Allow all egress"
#   }
# }

# resource "aws_route53_resolver_endpoint" "main" {
#   name      = "main"
#   direction = "OUTBOUND"

#   security_group_ids = [aws_security_group.resolver_endpoint.id]

#   ip_address {
#     subnet_id = aws_subnet.dns_resolver[0].id
#   }

#   ip_address {
#     subnet_id = aws_subnet.dns_resolver[1].id
#   }
# }