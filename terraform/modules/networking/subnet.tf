data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  all_private_subnets_cidr = cidrsubnet(aws_vpc.vpc.cidr_block, 1, 0)   # 0.0/17
  bastion_subnet_cidr_10   = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 0)   # 0.0/22
  ad_dc_subnet_cidr_10     = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 1)   # 4.0/22
  ad_other_cidr_10         = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 2)   # 8.0/22
  ml_subnet_cidr_10        = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 3)   # 12.0/22
  jaspersoft_cidr_10       = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 4)   # 16.0/22
  delta_internal_cidr_10   = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 5)   # 20.0/22
  # dns_resolver_cidr_10   = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 6)   # 24.0/10
  public_cidr_10           = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 32)  # 128.0/22
  vpc_endpoints_cidr_8     = cidrsubnet(aws_vpc.vpc.cidr_block, 8, 253) # 253.0/24
  firewall_cidr_8          = cidrsubnet(aws_vpc.vpc.cidr_block, 8, 254) # 254.0/24
  nat_gateway_cidr_8       = cidrsubnet(aws_vpc.vpc.cidr_block, 8, 255) # 255.0/24
}

# tfsec:ignore:aws-ec2-no-public-ip-subnet
resource "aws_subnet" "public_subnets" {
  count                   = var.number_of_public_subnets
  cidr_block              = cidrsubnet(local.public_cidr_10, 2, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
}

resource "aws_subnet" "bastion_private_subnets" {
  count                   = 3
  cidr_block              = cidrsubnet(local.bastion_subnet_cidr_10, 2, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "bastion-private-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
}

resource "aws_subnet" "ad_dc_private_subnets" {
  count                   = var.number_of_ad_subnets
  cidr_block              = cidrsubnet(local.ad_dc_subnet_cidr_10, 2, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "domain-controller-private-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
}

resource "aws_subnet" "ldaps_ca_server" {
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = cidrsubnet(local.ad_other_cidr_10, 2, 0)
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = false
  tags                    = { Name = "ca-server-private-subnet-${var.environment}" }
}

resource "aws_subnet" "ad_management_server" {
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = cidrsubnet(local.ad_other_cidr_10, 2, 1)
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = false
  tags                    = { Name = "ad-management-private-subnet-${var.environment}" }
}

resource "aws_subnet" "ml_private_subnets" {
  count                   = 3
  cidr_block              = cidrsubnet(local.ml_subnet_cidr_10, 2, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "marklogic-private-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
}

resource "aws_subnet" "delta_internal" {
  count                   = 3
  cidr_block              = cidrsubnet(local.delta_internal_cidr_10, 2, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "delta-internal-private-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
}

resource "aws_subnet" "jaspersoft" {
  cidr_block              = cidrsubnet(local.jaspersoft_cidr_10, 2, 0)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags                    = { Name = "jasper-server-private-subnet-${var.environment}" }
}

resource "aws_subnet" "vpc_endpoints_subnet" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = local.vpc_endpoints_cidr_8
  vpc_id            = aws_vpc.vpc.id
  tags              = { Name = "vpc-endpoints-subnet-${var.environment}" }
}

resource "aws_subnet" "firewall" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = local.firewall_cidr_8
  vpc_id            = aws_vpc.vpc.id
  tags              = { Name = "vpc-network-firewall-subnet-${var.environment}" }
}

resource "aws_subnet" "nat_gateway" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = local.nat_gateway_cidr_8
  vpc_id            = aws_vpc.vpc.id
  tags              = { Name = "nat-gateway-${var.environment}" }
}

# resource "aws_subnet" "dns_resolver" {
#   count             = 2
#   availability_zone = data.aws_availability_zones.available.names[count.index]
#   cidr_block        = cidrsubnet(local.dns_resolver_cidr_10, 1, count.index)
#   vpc_id            = aws_vpc.vpc.id
#   tags              = { Name = "route-53-outbound-resolver-${var.environment}" }
# }
