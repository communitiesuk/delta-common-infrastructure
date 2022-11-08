# Send peering request to Digital Space
locals {
  peering_vpc_account = "090682378586"
  peering_vpc_id      = "vpc-05d6334ddb1456837"
  peering_vpc_cidr    = "192.168.0.0/16"
  server_ip           = "192.168.148.6"
}

# We could auto accept, but we'll pretend they're in different accounts
resource "aws_vpc_peering_connection" "to_datamart_staging" {
  peer_owner_id = local.peering_vpc_account
  peer_vpc_id   = local.peering_vpc_id
  vpc_id        = module.networking.vpc.id

  tags = {
    Name = "vpc-peer-staging-to-datamart"
  }
}

output "datamart_vpc_peering_connection_id" {
  value = aws_vpc_peering_connection.to_staging.id
}

resource "aws_vpc_peering_connection_options" "to_datamart_staging" {
  vpc_peering_connection_id = aws_vpc_peering_connection.to_staging.id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}