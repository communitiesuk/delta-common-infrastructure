data "aws_region" "current" {}

data "aws_secretsmanager_secret" "mailhog_auth_file" {
  name = "mailhog-auth-file-${var.environment}"
}
