data "aws_vpc_endpoint_service" "ec2" {
  service      = "ec2"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "ec2" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.ec2.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.aws_service_vpc_endpoints.id]
  subnet_ids          = [aws_subnet.vpc_endpoints_subnet.id]
  private_dns_enabled = true
  tags = {
    Name = "ec2-private-endpoint-${var.environment}"
  }
}
