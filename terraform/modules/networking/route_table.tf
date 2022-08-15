resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = var.default_tags
}

resource "aws_route_table_association" "route_table_association_subnet" {
  count          = var.number_of_public_subnets
  subnet_id      = aws_subnet.pub_subnet.*.id[count.index]
  route_table_id = aws_route_table.public.id
}
