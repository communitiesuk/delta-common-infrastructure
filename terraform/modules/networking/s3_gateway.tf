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
    actions = ["s3:GetObject", "s3:GetBucketLocation", "s3:ListBucket", "s3:GetEncryptionConfiguration"]
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
  }

  statement {
    sid = "WriteBucketsInCurrentAccount"
    actions = [
      "s3:GetObject",
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:GetBucketAcl",
      "s3:GetObjectAcl",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
      "s3:PutObjectTagging",
      "s3:GetObjectTagging",
      "s3:DeleteObjectTagging",
    ]
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

  statement {
    sid     = "AWSBuckets"
    actions = ["s3:GetObject", "s3:ListBucket", "s3:GetEncryptionConfiguration"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      # https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent-minimum-s3-permissions.html
      "arn:aws:s3:::aws-ssm-${data.aws_region.current.name}/*",
      "arn:aws:s3:::aws-windows-downloads-${data.aws_region.current.name}/*",
      "arn:aws:s3:::amazon-ssm-${data.aws_region.current.name}/*",
      "arn:aws:s3:::amazon-ssm-packages-${data.aws_region.current.name}/*",
      "arn:aws:s3:::${data.aws_region.current.name}-birdwatcher-prod/*",
      "arn:aws:s3:::patch-baseline-snapshot-${data.aws_region.current.name}/*",
      "arn:aws:s3:::aws-ssm-distributor-file-${data.aws_region.current.name}/*",
      "arn:aws:s3:::aws-ssm-document-attachments-${data.aws_region.current.name}/*",
      # For the CA Server quickstart
      "arn:aws:s3:::aws-quickstart-${data.aws_region.current.name}/*",
      # ECS https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html#ecr-minimum-s3-perms
      "arn:aws:s3:::prod-${data.aws_region.current.name}-starport-layer-bucket/*",
    ]
  }
}
