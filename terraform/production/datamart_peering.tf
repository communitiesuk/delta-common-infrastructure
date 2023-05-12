# Send peering request to Digital Space
locals {
  datamart_peering_vpc_account = "090682378586"
  datamart_peering_vpc_id      = "vpc-47219022"
  datamart_peering_vpc_cidr    = "192.168.0.0/16"
  datamart_server_ip           = "192.168.9.240"
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
