data "aws_vpc_endpoint_service" "ecr_dkr" {
  service      = "ecr.dkr"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.ecr_dkr.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.aws_service_vpc_endpoints.id]
  subnet_ids          = aws_subnet.vpc_endpoints_subnets[*].id
  policy              = data.aws_iam_policy_document.ecr_dkr_endpoint.json
  private_dns_enabled = true
  tags = {
    Name = "ecr-dkr-private-endpoint-${var.environment}"
  }
}

data "aws_vpc_endpoint_service" "ecr_api" {
  service      = "ecr.api"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.ecr_api.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.aws_service_vpc_endpoints.id]
  subnet_ids          = aws_subnet.vpc_endpoints_subnets[*].id
  policy              = data.aws_iam_policy_document.ecr_api_endpoint.json
  private_dns_enabled = true
  tags = {
    Name = "ecr-api-private-endpoint-${var.environment}"
  }
}

data "aws_iam_policy_document" "ecr_api_endpoint" {
  statement {
    actions = ["ecr:GetAuthorizationToken"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "ecr_dkr_endpoint" {
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
    resources = ["arn:aws:ecr:${data.aws_region.current.name}:${var.ecr_repo_account_id}:*"]
  }
}
