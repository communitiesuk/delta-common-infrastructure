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
