data "aws_vpc_endpoint_service" "ssm" {
  service      = "ssm"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.ssm.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.aws_service_vpc_endpoints.id]
  subnet_ids          = [aws_subnet.vpc_endpoints_subnet.id]
  private_dns_enabled = true
  tags = {
    Name = "ssm-private-endpoint-${var.environment}"
  }
}

data "aws_vpc_endpoint_service" "ssmmessages" {
  service      = "ssmmessages"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.ssmmessages.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.aws_service_vpc_endpoints.id]
  subnet_ids          = [aws_subnet.vpc_endpoints_subnet.id]
  private_dns_enabled = true
  tags = {
    Name = "ssmmessages-private-endpoint-${var.environment}"
  }
}

data "aws_vpc_endpoint_service" "ec2messages" {
  service      = "ec2messages"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.ec2messages.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.aws_service_vpc_endpoints.id]
  subnet_ids          = [aws_subnet.vpc_endpoints_subnet.id]
  private_dns_enabled = true
  tags = {
    Name = "ec2messages-private-endpoint-${var.environment}"
  }
}
