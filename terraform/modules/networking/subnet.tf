data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "ml_private_subnets" {
  count                   = 3
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
}

resource "aws_subnet" "ad_subnet" {
  count                   = var.number_of_ad_subnets
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index + 3)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
}

# tfsec:ignore:aws-ec2-no-public-ip-subnet
resource "aws_subnet" "public_subnet" {
  count                   = var.number_of_public_subnets
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index + 128)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "Public subnet ${count.index}" }
}

resource "aws_subnet" "ad_management_server" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = "10.0.224.0/24"
  vpc_id            = aws_vpc.vpc.id
  # tfsec:ignore:aws-ec2-no-public-ip-subnet Intentionally public
  map_public_ip_on_launch = true
}

resource "aws_subnet" "ldaps_ca_server" {
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = "10.0.225.0/24"
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = false
}

resource "aws_subnet" "nat_gateway" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, 226)
  vpc_id            = aws_vpc.vpc.id
}
