resource "aws_eip" "nat_gateway" {
  vpc = true
}

resource "aws_shield_protection" "nat_gateway" {
  count        = var.apply_aws_shield_to_nat_gateway ? 1 : 0
  name         = "NAT Gateway Elastic IP Protection"
  resource_arn = "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:eip-allocation/${aws_eip.nat_gateway.id}"
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.nat_gateway.id

  tags = {
    Name = "nat-gateway-${var.environment}"
  }
}
