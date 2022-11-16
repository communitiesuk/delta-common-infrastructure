resource "aws_iam_role" "ml_iam_role" {
  name = "ml-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ml_attach" {
  role       = aws_iam_role.ml_iam_role.name
  policy_arn = aws_iam_policy.ml_instance_policy.arn
}

resource "aws_iam_instance_profile" "ml_instance_profile" {
  name = "ml-profile-${var.environment}"
  role = aws_iam_role.ml_iam_role.name
}

#tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_policy" "ml_instance_policy" {
  name        = "ml-instance-policy-${var.environment}"
  description = "Allows MarkLogic instances to perform necessary actions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2messages:GetMessages",
          "ec2:CreateTags",

          "ssm:UpdateInstanceInformation",
          "ssm:ListInstanceAssociations",
          "ssm:ListAssociations",
          "ssm:PutInventory",
          "ssm:UpdateInstanceAssociationStatus",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:CreateControlChannel",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "kms:GenerateDataKey",
          "kms:DescribeKey",
          "kms:Decrypt"
        ]
        Effect   = "Allow"
        Resource = [aws_kms_key.ml_logs_encryption_key.arn]
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:dynamodb:*:*:table/*MarkLogicDDBTable*"
      },
      {
        Action = [
          "ec2:AttachVolume",
          "ec2:CreateVolume"
        ]
        Effect   = "Allow"
        Resource = ["arn:aws:ec2:*:*:volume/*", "arn:aws:ec2:*:*:instance/*"]
      },
      {
        Action = [
          "sns:Publish"
        ]
        Effect   = "Allow"
        Resource = [aws_sns_topic.ml_logs.arn]
      }
    ]
  })
}

data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ml_ssm_managed" {
  role       = aws_iam_role.ml_iam_role.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}

resource "aws_iam_role_policy_attachment" "ml_dap_s3" {
  role       = aws_iam_role.ml_iam_role.name
  policy_arn = aws_iam_policy.ml_dap_s3.arn
}

resource "aws_iam_policy" "ml_dap_s3" {
  name        = "ml-instance-dap-s3-${var.environment}"
  description = "Allows MarkLogic instances to read and write the DAP export S3 bucket"

  policy = data.aws_iam_policy_document.ml_dap_s3.json
}

#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "ml_dap_s3" {
  statement {
    actions = ["s3:GetObject", "s3:GetBucketLocation", "s3:ListBucket", "s3:PutObject", "s3:DeleteObject"]
    effect  = "Allow"
    resources = [
      module.dap_export_bucket.bucket_arn,
      "${module.dap_export_bucket.bucket_arn}/*"
    ]
  }
}
