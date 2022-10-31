resource "aws_kms_key" "main" {
  enable_key_rotation = true
}

resource "aws_kms_alias" "main" {
  name          = var.kms_alias
  target_key_id = aws_kms_key.main.id
}

resource "aws_ecr_repository" "main" {
  name                 = var.repo_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.main.arn
  }
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = file("${path.module}/ecr_lifecycle_policy.json")
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
