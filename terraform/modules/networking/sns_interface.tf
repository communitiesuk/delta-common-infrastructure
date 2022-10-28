data "aws_vpc_endpoint_service" "sns" {
  service      = "sns"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "sns" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.sns.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.aws_service_vpc_endpoints.id]
  subnet_ids          = aws_subnet.vpc_endpoints_subnets[*].id
  private_dns_enabled = true
  tags = {
    Name = "sns-private-endpoint-${var.environment}"
  }
}

data "aws_iam_policy_document" "sns_endpoint" {
  statement {
    actions = ["sns:Publish"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
    resources = ["arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
  }
}
