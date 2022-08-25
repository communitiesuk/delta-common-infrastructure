resource "aws_route_table" "to_internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = var.default_tags
}

resource "aws_route_table_association" "ad_management_server" {
  subnet_id      = aws_subnet.ad_management_server.id
  route_table_id = aws_route_table.to_internet_gateway.id
}

resource "aws_route_table_association" "nat_gateway" {
  subnet_id      = aws_subnet.nat_gateway.id
  route_table_id = aws_route_table.to_internet_gateway.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = var.default_tags
}

resource "aws_route_table_association" "private" {
  count          = var.number_of_private_subnets
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private.id
}
