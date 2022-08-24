data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "private_subnet" {
  count                   = var.number_of_private_subnets
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 4, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = var.default_tags
}

resource "aws_subnet" "nat_gateway" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = "10.0.240.0/24"
  vpc_id            = aws_vpc.vpc.id
  tags              = var.default_tags
}