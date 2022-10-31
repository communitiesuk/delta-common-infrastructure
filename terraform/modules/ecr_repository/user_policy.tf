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
