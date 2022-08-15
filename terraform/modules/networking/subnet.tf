data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "pub_subnet" {
  count             = var.number_of_public_subnets
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index)
  vpc_id            = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = var.default_tags
}
