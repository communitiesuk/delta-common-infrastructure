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

# Used by the NodeManager template that the Marklogic template references
data "aws_vpc_endpoint_service" "autoscaling" {
  service      = "autoscaling"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "autoscaling" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.autoscaling.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.aws_service_vpc_endpoints.id]
  subnet_ids          = [aws_subnet.vpc_endpoints_subnet.id]
  private_dns_enabled = true
  tags = {
    Name = "autoscaling-private-endpoint-${var.environment}"
  }
}
