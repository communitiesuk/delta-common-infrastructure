resource "aws_route_table_association" "nat_gateway" {
  subnet_id      = aws_subnet.nat_gateway.id
  route_table_id = aws_route_table.nat_gateway_subnet_route_table.id
}

resource "aws_route_table_association" "firewall" {
  subnet_id      = aws_subnet.firewall.id
  route_table_id = aws_route_table.to_nat_gateway.id
}

resource "aws_route_table_association" "public" {
  count          = var.number_of_public_subnets
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.to_internet_gateway.id
}

resource "aws_route_table_association" "firewalled" {
  count          = length(local.firewall_config)
  subnet_id      = local.firewalled_subnets[count.index].id
  route_table_id = aws_route_table.private_to_firewall.id
}
