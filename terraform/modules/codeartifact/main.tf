resource "aws_kms_key" "codeartifact" {
  description         = "Codeartifact encryption key"
  enable_key_rotation = true
}

resource "aws_codeartifact_domain" "codeartifact_domain" {
  domain         = var.codeartifact_domain_name
  encryption_key = aws_kms_key.codeartifact.arn
}
