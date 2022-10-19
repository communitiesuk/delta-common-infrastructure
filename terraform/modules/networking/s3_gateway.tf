data "aws_vpc_endpoint_service" "s3" {
  service      = "s3"
  service_type = "Gateway"
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.vpc.id
  service_name = data.aws_vpc_endpoint_service.s3.service_name
  policy       = data.aws_iam_policy_document.s3_gateway.json
  tags = {
    Name = "s3-gateway-endpoint-${var.environment}"
  }
}

resource "aws_vpc_endpoint_route_table_association" "s3" {
  route_table_id  = aws_route_table.private_to_firewall.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

# Note that endpoint policies only limit access, credentials are still required to access private buckets
data "aws_iam_policy_document" "s3_gateway" {
  statement {
    sid     = "AmazonLinux2Yum"
    actions = ["s3:GetObject"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      "arn:aws:s3:::amazonlinux.${data.aws_region.current.name}.amazonaws.com/*",
      "arn:aws:s3:::amazonlinux-2-repos-${data.aws_region.current.name}/*",
    ]
  }

  statement {
    sid     = "ReadBucketsInCurrentAccount"
    actions = ["s3:GetObject", "s3:ListBucket"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      "arn:aws:s3:::*"
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:ResourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}
