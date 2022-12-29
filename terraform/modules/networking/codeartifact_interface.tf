data "aws_vpc_endpoint_service" "codeartifact_api" {
  service      = "codeartifact.api"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "codeartifact_api" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.codeartifact_api.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.aws_service_vpc_endpoints.id]
  subnet_ids          = aws_subnet.vpc_endpoints_subnets[*].id
  private_dns_enabled = true
  tags = {
    Name = "codeartifact-api-private-endpoint-${var.environment}"
  }
}

data "aws_vpc_endpoint_service" "codeartifact_repositories" {
  service      = "codeartifact.repositories"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "codeartifact_repositories" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.codeartifact_repositories.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.aws_service_vpc_endpoints.id]
  subnet_ids          = aws_subnet.vpc_endpoints_subnets[*].id
  private_dns_enabled = true
  tags = {
    Name = "codeartifact-repositories-private-endpoint-${var.environment}"
  }
}
