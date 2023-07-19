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
  github_runner_cidr_10    = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 6)   # 24.0/22
  delta_api_cidr_10        = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 7)   # 28.0/22
  cpm_private_cidr_10      = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 8)   # 32.0/22
  vpc_endpoints_cidr_10    = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 9)   # 36.0/22
  keycloak_cidr_10         = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 10)  # 40.0/22
  delta_website_cidr_10    = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 11)  # 44.0/22
  mailhog_cidr_10          = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 12)  # 48.0/22
  website_db_cidr_10       = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 13)  # 52.0/22
  auth_service_cidr_10     = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 14)  # 56.0/22
  public_cidr_10           = cidrsubnet(aws_vpc.vpc.cidr_block, 6, 32)  # 128.0/22
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

resource "aws_subnet" "delta_api" {
  count                   = 3
  cidr_block              = cidrsubnet(local.delta_api_cidr_10, 2, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "delta-api-private-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
}

resource "aws_subnet" "delta_website" {
  count                   = 3
  cidr_block              = cidrsubnet(local.delta_website_cidr_10, 2, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "delta-website-private-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
}

resource "aws_subnet" "jaspersoft" {
  count = 2

  cidr_block              = cidrsubnet(local.jaspersoft_cidr_10, 2, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "jasper-server-private-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
}

resource "aws_subnet" "github_runner" {
  cidr_block              = cidrsubnet(local.github_runner_cidr_10, 2, 0)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags                    = { Name = "github-runner-private-subnet-${var.environment}" }
}

resource "aws_subnet" "cpm_private" {
  count                   = 3
  cidr_block              = cidrsubnet(local.cpm_private_cidr_10, 2, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "cpm-private-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
}

resource "aws_subnet" "vpc_endpoints_subnets" {
  count             = var.number_of_vpc_endpoint_subnets
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(local.vpc_endpoints_cidr_10, 2, count.index)
  vpc_id            = aws_vpc.vpc.id
  tags              = { Name = "vpc-endpoints-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
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

resource "aws_subnet" "keycloak_private" {
  count                   = 3
  cidr_block              = cidrsubnet(local.keycloak_cidr_10, 2, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "keycloak-private-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
}

resource "aws_subnet" "mailhog" {
  count                   = var.mailhog_subnet == true ? 1 : 0
  cidr_block              = cidrsubnet(local.mailhog_cidr_10, 2, 0)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags                    = { Name = "mailhog-private-subnet-${var.environment}" }
}

resource "aws_subnet" "delta_website_db" {
  count                   = 3
  cidr_block              = cidrsubnet(local.website_db_cidr_10, 2, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "delta-website-db-private-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
}

moved {
  //noinspection HILUnresolvedReference
  from = aws_subnet.redis
  to   = aws_subnet.delta_website_db
}

resource "aws_subnet" "auth_service" {
  count                   = 3
  cidr_block              = cidrsubnet(local.auth_service_cidr_10, 2, count.index)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "auth-service-private-subnet-${data.aws_availability_zones.available.names[count.index]}-${var.environment}" }
}
