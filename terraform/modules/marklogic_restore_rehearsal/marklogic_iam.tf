resource "aws_iam_role" "ml_iam_role" {
  name = "ml-role-restore-rehearsal"

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
  name = "ml-profile-restore-rehearsal"
  role = aws_iam_role.ml_iam_role.name
}

#tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_policy" "ml_instance_policy" {
  name        = "ml-instance-policy-restore-rehearsal"
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
          "ec2:AttachVolume"
        ]
        Effect   = "Allow"
        Resource = ["arn:aws:ec2:*:*:volume/*", "arn:aws:ec2:*:*:instance/*"]
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

resource "aws_iam_role_policy_attachment" "ml_s3_backups" {
  role       = aws_iam_role.ml_iam_role.name
  policy_arn = aws_iam_policy.ml_s3_backups.arn
}

resource "aws_iam_policy" "ml_s3_backups" {
  name        = "ml-s3-backups-access-for-rehearsal"
  description = "Allows MarkLogic instances to read and write their S3 Backups bucket"

  policy = data.aws_iam_policy_document.ml_s3_backups.json
}

#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "ml_s3_backups" {
  statement {
    actions = [
      # Just read actions, not write
      "s3:GetEncryptionConfiguration", "s3:GetObject", "s3:GetBucketLocation", "s3:ListBucket",
      "s3:ListBucketMultipartUploads", "s3:ListMultipartUploadParts",
    ]
    effect = "Allow"
    resources = [
      var.daily_backup_bucket_arn,
      "${var.daily_backup_bucket_arn}/*",
      var.weekly_backup_bucket_arn,
      "${var.weekly_backup_bucket_arn}/*"
    ]
  }
  statement {
    actions   = ["kms:GenerateDataKey", "kms:DescribeKey", "kms:Decrypt"]
    effect    = "Allow"
    resources = [var.backup_key]
  }
}
