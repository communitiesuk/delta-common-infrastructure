# Peering experiment
# Pretending to be our side of the VPC, i.e. our bastion + management server should be able to access their DC

locals {
  peering_connection_id = "pcx-0b8a9e932932e2567"
  peering_vpc_cidr      = "10.0.0.0/16"
}

resource "aws_vpc_peering_connection_accepter" "from_test" {
  vpc_peering_connection_id = local.peering_connection_id
  auto_accept               = true

  tags = {
    Name        = "vpc-peer-test-to-staging"
    environment = "shared"
  }
}

data "aws_route_table" "ad_management_server" {
  subnet_id = module.networking.ad_management_server_subnet.id
}

resource "aws_route" "ad_management_to_peer" {
  route_table_id            = data.aws_route_table.ad_management_server.route_table_id
  destination_cidr_block    = local.peering_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.from_test.id
}

data "aws_route_table" "bastion" {
  subnet_id = module.networking.bastion_private_subnets[0].id
}

resource "aws_route" "bastion_to_peer" {
  route_table_id            = data.aws_route_table.bastion.route_table_id
  destination_cidr_block    = local.peering_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.from_test.id
}

resource "aws_security_group_rule" "bastion_to_peer" {
  security_group_id = module.bastion.bastion_security_group_id
  description       = "Bastion to peered VPC"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [local.peering_vpc_cidr]
}

# The AD management server's SG already allows open egress

# Traffic is allowed back through the ACL using the open_ingress_cidrs variable on the Networking module (see main.tf)

# As recommended here https://docs.aws.amazon.com/directoryservice/latest/admin-guide/ms_ad_tutorial_setup_trust_prepare_mad_between_2_managed_ad_domains.html#tutorial_setup_trust_open_vpc_between_2_managed_ad_domains
# Presumably egress to the other DCs would be enough, definitely needed for DNS, not sure if anything else
# tfsec:ignore:aws-vpc-no-public-egress-sgr
resource "aws_security_group_rule" "domain_controller_egress" {

  security_group_id = module.active_directory.domain_controller_security_group_id
  description       = "DC Open Egress"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
