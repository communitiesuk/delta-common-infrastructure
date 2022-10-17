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
  name        = "ml_instance_policy"
  path        = "/"
  description = "Allows MarkLogic instances to perform necessary actions"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
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

          # TODO DT-58 Should be limited to specific keys
          "kms:GenerateDataKey",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Effect   = "Allow"
        Resource = "*"
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
