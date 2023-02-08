# Send peering request to Digital Space
locals {
  datamart_peering_vpc_account = "090682378586"
  datamart_peering_vpc_id      = "vpc-47219022"
  datamart_peering_vpc_cidr    = "192.168.0.0/16"
  datamart_server_ip           = "192.168.7.253"
}

data "aws_route_table" "ad_management_server" {
  subnet_id = module.networking.ad_management_server_subnet.id
}

resource "aws_vpc_peering_connection" "to_datamart_production" {
  peer_owner_id = local.datamart_peering_vpc_account
  peer_vpc_id   = local.datamart_peering_vpc_id
  vpc_id        = module.networking.vpc.id

  tags = {
    Name = "vpc-peer-production-to-datamart"
  }
}

output "datamart_vpc_peering_connection_id" {
  value = aws_vpc_peering_connection.to_datamart_production.id
}

resource "aws_vpc_peering_connection_options" "to_datamart_production" {
  vpc_peering_connection_id = aws_vpc_peering_connection.to_datamart_production.id
  # we don't have permission to modify the accepter side's settings

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_route" "ad_management_to_datamart_peer" {
  route_table_id            = data.aws_route_table.ad_management_server.route_table_id
  destination_cidr_block    = local.datamart_peering_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.to_datamart_production.id
}

# The AD management server's SG already allows open egress

# Traffic is allowed back through the ACL using the open_ingress_cidrs variable on the Networking module (see main.tf)

# As recommended here https://docs.aws.amazon.com/directoryservice/latest/admin-guide/ms_ad_tutorial_setup_trust_prepare_mad_between_2_managed_ad_domains.html#tutorial_setup_trust_open_vpc_between_2_managed_ad_domains
# Presumably egress to the other DCs would be enough, definitely needed for DNS, not sure if anything else
# tfsec:ignore:aws-vpc-no-public-egress-sgr
resource "aws_security_group_rule" "domain_controller_egress_to_datamart" {

  security_group_id = module.active_directory.domain_controller_security_group_id
  description       = "DC Open Egress"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [local.datamart_peering_vpc_cidr]
}
