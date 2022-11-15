# Send peering request to Digital Space
locals {
  datamart_peering_vpc_account = "090682378586"
  datamart_peering_vpc_id      = "vpc-05d6334ddb1456837"
  datamart_peering_vpc_cidr    = "192.168.0.0/16"
  datamart_server_ip           = "192.168.148.6"
}

resource "aws_vpc_peering_connection" "to_datamart_staging" {
  peer_owner_id = local.datamart_peering_vpc_account
  peer_vpc_id   = local.datamart_peering_vpc_id
  vpc_id        = module.networking.vpc.id

  tags = {
    Name = "vpc-peer-staging-to-datamart"
  }
}

output "datamart_vpc_peering_connection_id" {
  value = aws_vpc_peering_connection.to_datamart_staging.id
}

resource "aws_vpc_peering_connection_options" "to_datamart_staging" {
  vpc_peering_connection_id = aws_vpc_peering_connection.to_datamart_staging.id
  # we don't have permission to modify the accepter side's settings

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

# Note this route table is also used by the bastion server
resource "aws_route" "ad_management_to_datamart_peer" {
  route_table_id            = data.aws_route_table.ad_management_server.route_table_id
  destination_cidr_block    = local.datamart_peering_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.to_datamart_staging.id
}

resource "aws_security_group_rule" "bastion_to_datamart_peer" {
  security_group_id = module.bastion.bastion_security_group_id
  description       = "Bastion to peered VPC"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [local.datamart_peering_vpc_cidr]
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