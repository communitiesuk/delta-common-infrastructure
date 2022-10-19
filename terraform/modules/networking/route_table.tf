# Simple one first, public subnets should route internet traffic to the Internet Gateway
resource "aws_route_table" "to_internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "to-igw-route-table-${var.environment}"
  }
}

# Private subnets should instead have all non-local traffic routed to the Firewall
resource "aws_route_table" "private_to_firewall" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = one(one(one(aws_networkfirewall_firewall.main.firewall_status).sync_states).attachment).endpoint_id
  }

  tags = {
    Name = "to-firewall-route-table-${var.environment}"
  }
}

# Then the Firewall should forward to the NAT Gateway
# Private subnets that aren't yet firewalled can also route traffic straight here
resource "aws_route_table" "to_nat_gateway" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "to-nat-route-table-${var.environment}"
  }
}

# And finally the NAT gateway should send internet bound traffic out to the gateway
resource "aws_route" "nat_gateway_to_internet" {
  route_table_id         = aws_route_table.nat_gateway_subnet_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

# Coming back the Internet Gateway will route traffic to the NAT Gateway - that's the default, all good
# Then the NAT Gateway should route traffic destined for firewalled subnets back through the firewall first
resource "aws_route" "nat_gateway_back_to_firewall" {
  for_each = { for subnet in local.firewalled_subnets : subnet.tags.Name => subnet }

  # More specific routes override less specific ones (by prefix length)
  route_table_id         = aws_route_table.nat_gateway_subnet_route_table.id
  destination_cidr_block = each.value.cidr_block
  vpc_endpoint_id        = one(one(one(aws_networkfirewall_firewall.main.firewall_status).sync_states).attachment).endpoint_id
}

resource "aws_route_table" "nat_gateway_subnet_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "nat-gateway-subnet-route-table-${var.environment}"
  }
}
