variable "domain" {
  type = string
}

resource "aws_ses_domain_identity" "main" {
  domain = var.domain
}

output "validation_record" {
  value = {
    record_name  = "_amazonses.${var.domain}."
    record_type  = "TXT"
    record_value = aws_ses_domain_identity.main.verification_token
  }
}
