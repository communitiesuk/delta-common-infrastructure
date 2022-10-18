data "aws_vpc_endpoint_service" "secrets_manager" {
  service      = "secretsmanager"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.secrets_manager.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.secrets_manager_endpoint.id]
  subnet_ids          = [aws_subnet.vpc_endpoints_subnet.id]
  policy              = data.aws_iam_policy_document.secret_manager_endpoint.json
  private_dns_enabled = true
  tags = {
    Name = "secrets-manager-private-endpoint-${var.environment}"
  }
}

resource "aws_security_group" "secrets_manager_endpoint" {
  name        = "vpc-endpoint-${var.environment}"
  description = "VPC Endpoint security group"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
}

# Note that endpoint policies only limit access, credentials to access a given secret are still required
data "aws_iam_policy_document" "secret_manager_endpoint" {
  statement {
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
    resources = ["arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:*"]
  }
}
