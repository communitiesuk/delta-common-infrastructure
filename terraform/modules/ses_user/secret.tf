resource "aws_secretsmanager_secret" "ses_user" {
  name                    = "tf-smtp-${var.username}"
  description             = "Managed by Terraform, do not update manually"
  kms_key_id              = aws_kms_key.deploy_secrets.arn
  recovery_window_in_days = 0

  tags = {
    "delta-marklogic-deploy-read" = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "ses_user" {
  secret_id = aws_secretsmanager_secret.ses_user.id
  secret_string = jsonencode({
    username = aws_iam_access_key.smtp_user.id
    password = aws_iam_access_key.smtp_user.ses_smtp_password_v4
  })
}
