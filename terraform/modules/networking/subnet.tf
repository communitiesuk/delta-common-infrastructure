data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "private_subnet" {
  count                   = 3
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "private-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
}

resource "aws_subnet" "ad_subnet" {
  count                   = var.number_of_ad_subnets
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index + 3)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "domain-controller-private-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
}

resource "aws_subnet" "ml_private_subnets" {
  count                   = 3
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index + 6)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "marklogic-private-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
}

resource "aws_subnet" "japsersoft_private_subnet" {
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, 9)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags                    = { Name = "jasper-server-private-subnet-${var.environment}" }
}

# tfsec:ignore:aws-ec2-no-public-ip-subnet
resource "aws_subnet" "public_subnet" {
  count                   = var.number_of_public_subnets
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index + 128)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
}

resource "aws_subnet" "ldaps_ca_server" {
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = "10.0.225.0/24"
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = false
  tags                    = { Name = "ca-server-private-subnet-${var.environment}" }
}

resource "aws_subnet" "nat_gateway" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, 226)
  vpc_id            = aws_vpc.vpc.id
  tags              = { Name = "nat-gateway-${var.environment}" }
}
