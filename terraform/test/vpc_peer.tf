# Peering experiment
# Pretending to be the Datamart side, allowing ingress to domain controllers

locals {
  peering_vpc_account = "486283582667"
  peering_vpc_id      = "vpc-035b7b1626b9b5670"
  peering_vpc_cidr    = "10.20.0.0/16"
}

# We could auto accept, but we'll pretend they're in different accounts
resource "aws_vpc_peering_connection" "to_staging" {
  peer_owner_id = local.peering_vpc_account
  peer_vpc_id   = local.peering_vpc_id
  vpc_id        = module.networking.vpc.id

  tags = {
    Name        = "vpc-peer-test-to-staging"
    environment = "shared"
  }
}

output "vpc_peering_connection_id" {
  value = aws_vpc_peering_connection.to_staging.id
}

resource "aws_vpc_peering_connection_options" "to_staging" {
  vpc_peering_connection_id = aws_vpc_peering_connection.to_staging.id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

data "aws_route_table" "ad_dcs" {
  subnet_id = module.networking.ad_private_subnets[0].id
}

resource "aws_route" "ad_dcs_to_peer" {
  route_table_id            = data.aws_route_table.ad_dcs.route_table_id
  destination_cidr_block    = local.peering_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.to_staging.id
}

resource "aws_network_acl" "ad_peering_replacement_acl" {
  vpc_id = module.networking.vpc.id

  # Allow all intra-VPC traffic
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = module.networking.vpc.cidr_block
    from_port  = 0
    to_port    = 0
  }

  # Allow peered traffic
  ingress {
    protocol   = -1
    rule_no    = 200
    action     = "allow"
    cidr_block = local.peering_vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Open egress
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    "Name" = "ad-peering-acl-test"
  }
}

resource "aws_network_acl_association" "ad_peering_replacement_acl" {
  count          = length(module.networking.ad_private_subnets)
  network_acl_id = aws_network_acl.ad_peering_replacement_acl.id
  subnet_id      = module.networking.ad_private_subnets[count.index].id
}

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
