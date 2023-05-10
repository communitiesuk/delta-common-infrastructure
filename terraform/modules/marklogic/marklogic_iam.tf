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

resource "aws_iam_role_policy_attachment" "extra_attach" {
  role       = aws_iam_role.ml_iam_role.name
  policy_arn = var.extra_instance_policy_arn
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
          "ec2:AttachVolume"
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

resource "aws_iam_role_policy_attachment" "ml_s3_backups" {
  role       = aws_iam_role.ml_iam_role.name
  policy_arn = aws_iam_policy.ml_s3_backups.arn
}

resource "aws_iam_policy" "ml_s3_backups" {
  name        = "ml-instance-s3-backups-${var.environment}"
  description = "Allows MarkLogic instances to read and write their S3 Backups bucket"

  policy = data.aws_iam_policy_document.ml_s3_backups.json
}

#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "ml_s3_backups" {
  statement {
    actions = [
      "s3:GetEncryptionConfiguration", "s3:GetObject", "s3:GetBucketLocation", "s3:ListBucket", "s3:PutObject", "s3:DeleteObject",
      "s3:AbortMultipartUpload", "s3:ListBucketMultipartUploads", "s3:ListMultipartUploadParts",
    ]
    effect = "Allow"
    resources = [
      module.cpm_backup_bucket.bucket_arn,
      "${module.cpm_backup_bucket.bucket_arn}/*",
      module.delta_backup_bucket.bucket_arn,
      "${module.delta_backup_bucket.bucket_arn}/*",
    ]
  }
  statement {
    actions   = ["kms:GenerateDataKey", "kms:DescribeKey", "kms:Decrypt"]
    effect    = "Allow"
    resources = [aws_kms_key.ml_backup_bucket_key.arn]
  }
}

# Allowing access to a single bucket seems reasonable
# tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_policy" "ml_cloudwatch_ssm" {
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject"
        ],
        Effect   = "Allow"
        Resource = "${module.config_files_bucket.bucket_arn}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ml_cloudwatch_ssm" {
  role       = aws_iam_role.ml_iam_role.name
  policy_arn = aws_iam_policy.ml_cloudwatch_ssm.arn
}

resource "aws_iam_role_policy_attachment" "ml_cloudwatch" {
  role       = aws_iam_role.ml_iam_role.name
  policy_arn = aws_iam_policy.ml_cloudwatch.arn
}

resource "aws_iam_policy" "ml_cloudwatch" {
  name        = "ml-instance-logs-${var.environment}"
  description = "Allows MarkLogic instances to write logs to CloudWatch"

  policy = data.aws_iam_policy_document.ml_cloudwatch.json
}

# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "ml_cloudwatch" {
  statement {
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.app_log_group_base_name}*"]
  }

  statement {
    actions = [
      "cloudwatch:PutMetricData",
      "ec2:DescribeVolumes",
      "ec2:DescribeTags"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "ml_asg_patching" {
  role       = aws_iam_role.ml_iam_role.name
  policy_arn = aws_iam_policy.ml_asg_patching.arn
}

resource "aws_iam_policy" "ml_asg_patching" {
  name        = "ml-instance-asg-${var.environment}-patching"
  description = "Allow MarkLogic instances to manage ASG standby and allows retrieval of login details for patching"

  policy = data.aws_iam_policy_document.ml_asg_patching.json
}

# No convenient way to limit, and these policies aren't too dangerous
# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "ml_asg_patching" {
  statement {
    actions = [
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:EnterStandby",
      "autoscaling:ExitStandby"
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [data.aws_secretsmanager_secret_version.ml_admin_user.arn]
  }
}
