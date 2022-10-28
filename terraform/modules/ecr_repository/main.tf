resource "aws_kms_key" "ecr_kms" {
  enable_key_rotation = true
}

resource "aws_ecr_repository" "main" {
  name                 = var.repo_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr_kms.arn
  }
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = file("${path.module}/ecr_lifecycle_policy.json")
}


resource "aws_iam_user_policy" "main" {
  name = "push-access-to-ecr-for-${var.repo_name}"
  user = var.push_user

  policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ecr:CompleteLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:DescribeImages",
            "ecr:InitiateLayerUpload",
            "ecr:BatchCheckLayerAvailability",
            "ecr:PutImage"
          ]
          Resource = [
            aws_ecr_repository.main.arn
          ]
          Sid = "1"
        },
        {
          Effect   = "Allow"
          Action   = ["ecr:GetAuthorizationToken"]
          Resource = "*"
          Sid      = "2"
        }
      ]
    }
  )
}

resource "aws_ecr_repository_policy" "read" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "AllowPullFromDevAccount",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : "arn:aws:iam::${var.dev_aws_account_id}:root"
          },
          "Action" : [
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
          ]
        }
      ]
    }
  )
}
