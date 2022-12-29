data "aws_vpc_endpoint_service" "codedeploy" {
  service      = "codedeploy"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "codedeploy" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.codedeploy.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.aws_service_vpc_endpoints.id]
  subnet_ids          = aws_subnet.vpc_endpoints_subnets[*].id
  private_dns_enabled = true
  tags = {
    Name = "codedeploy-private-endpoint-${var.environment}"
  }
}

data "aws_vpc_endpoint_service" "codedeploy_commands_secure" {
  service      = "codedeploy-commands-secure"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "codedeploy_commands_secure" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.codedeploy_commands_secure.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.aws_service_vpc_endpoints.id]
  subnet_ids          = aws_subnet.vpc_endpoints_subnets[*].id
  private_dns_enabled = true
  tags = {
    Name = "codedeploy-commands-secure-private-endpoint-${var.environment}"
  }
}
