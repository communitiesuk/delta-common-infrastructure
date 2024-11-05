variable "vpc_id" {
  type = string
}

variable "username" {
  type = string
}

variable "ses_identity_arns" {
  type = list(string)
}


variable "from_address_patterns" {
  type        = list(string)
  description = "for example 'marketing+.*@example.com'"
}

variable "environment" {
  type = string
}

# One of a kind
# tfsec:ignore:aws-iam-no-user-attached-policies
resource "aws_iam_user" "smtp_user" {
  name = var.username

  lifecycle {
    ignore_changes = [tags, tags_all] # AWS uses tags for access key descriptions
  }
}

resource "aws_iam_access_key" "smtp_user" {
  user = aws_iam_user.smtp_user.name
}

resource "aws_kms_key" "deploy_secrets" {
  description         = "deploy-secrets-${var.username}"
  enable_key_rotation = true

  tags = {
    "terraform-plan-read" = true
  }
}

resource "aws_kms_alias" "deploy_secrets" {
  name          = "alias/deploy-secrets-${var.username}"
  target_key_id = aws_kms_key.deploy_secrets.key_id
}

data "aws_iam_policy_document" "ses_sender" {
  statement {
    actions   = ["ses:SendRawEmail"]
    resources = var.ses_identity_arns
    condition {
      test     = "StringLike"
      variable = "ses:FromAddress"
      values   = var.from_address_patterns
    }
  }
}

resource "aws_iam_policy" "ses_sender" {
  name        = "ses-sender-${var.username}"
  description = "Allows sending of e-mails via Simple Email Service"
  policy      = data.aws_iam_policy_document.ses_sender.json
}

resource "aws_iam_user_policy_attachment" "main" {
  user       = aws_iam_user.smtp_user.name
  policy_arn = aws_iam_policy.ses_sender.arn
}

output "smtp_username" {
  value = aws_iam_access_key.smtp_user.id
}

output "smtp_password" {
  value     = aws_iam_access_key.smtp_user.ses_smtp_password_v4
  sensitive = true
}

output "deploy_secret_arn"
{
  value   = aws_kms_key.deploy_secrets.arn
}
