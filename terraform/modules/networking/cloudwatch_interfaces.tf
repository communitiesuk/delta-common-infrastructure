data "aws_vpc_endpoint_service" "cloudwatch" {
  service      = "monitoring"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "cloudwatch" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.cloudwatch.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.aws_service_vpc_endpoints.id]
  subnet_ids          = aws_subnet.vpc_endpoints_subnets[*].id
  policy              = data.aws_iam_policy_document.cloudwatch_endpoint.json
  private_dns_enabled = true
  tags = {
    Name = "cloudwatch-private-endpoint-${var.environment}"
  }
}

data "aws_iam_policy_document" "cloudwatch_endpoint" {
  statement {
    actions = ["cloudwatch:PutMetricData"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
    resources = ["*"]
  }
}

data "aws_vpc_endpoint_service" "cloudwatch_logs" {
  service      = "logs"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.cloudwatch_logs.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.aws_service_vpc_endpoints.id]
  subnet_ids          = aws_subnet.vpc_endpoints_subnets[*].id
  policy              = data.aws_iam_policy_document.cloudwatch_logs_endpoint.json
  private_dns_enabled = true
  tags = {
    Name = "cloudwatch-logs-private-endpoint-${var.environment}"
  }
}

data "aws_iam_policy_document" "cloudwatch_logs_endpoint" {
  statement {
    actions = [
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutRetentionPolicy"
    ]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
    resources = ["*"]
  }
}
