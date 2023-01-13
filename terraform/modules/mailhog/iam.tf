resource "aws_iam_role" "main" {
  name = "mailhog-role-${var.environment}"
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

resource "aws_iam_instance_profile" "main" {
  name = "mailhog-profile-${var.environment}"
  role = aws_iam_role.main.name
}

locals {
  iam_role_managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

resource "aws_iam_role_policy_attachment" "managed_policies" {
  count      = length(local.iam_role_managed_policy_arns)
  role       = aws_iam_role.main.name
  policy_arn = element(local.iam_role_managed_policy_arns, count.index)
}

resource "aws_iam_policy" "read_auth_file" {
  name        = "mailhog-read-auth-file-${var.environment}"
  description = "Read MailHog basic auth file"

  policy = data.aws_iam_policy_document.read_auth_file.json
}

data "aws_iam_policy_document" "read_auth_file" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    effect    = "Allow"
    resources = [data.aws_secretsmanager_secret.mailhog_auth_file.arn]
  }
}

resource "aws_iam_role_policy_attachment" "read_auth_file" {
  role       = aws_iam_role.main.name
  policy_arn = aws_iam_policy.read_auth_file.arn
}
