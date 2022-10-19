resource "aws_vpc_dhcp_options" "dns_resolver" {
  domain_name_servers = var.dns_servers
  # TODO DT-58 is this intentional?
  domain_name = "eu-west-1.compute.internal"
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = aws_vpc.vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.dns_resolver.id
}
