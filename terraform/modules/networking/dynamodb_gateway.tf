data "aws_vpc_endpoint_service" "dynamodb" {
  service      = "dynamodb"
  service_type = "Gateway"
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.vpc.id
  service_name = data.aws_vpc_endpoint_service.dynamodb.service_name
  policy       = data.aws_iam_policy_document.dynamodb_gateway.json
  tags = {
    Name = "dynamodb-gateway-endpoint-${var.environment}"
  }
}

resource "aws_vpc_endpoint_route_table_association" "dynamodb" {
  route_table_id  = aws_route_table.private_to_firewall.id
  vpc_endpoint_id = aws_vpc_endpoint.dynamodb.id
}

data "aws_iam_policy_document" "dynamodb_gateway" {
  statement {
    sid = "AccessTablesInCurrentAccount"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:UpdateItem"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}
