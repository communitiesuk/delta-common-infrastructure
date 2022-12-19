variable "domain" {
  type = string
}

resource "aws_ses_domain_identity" "main" {
  domain = var.domain

  # We ask DLUHC to make DNS records based on this
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ses_domain_dkim" "main" {
  domain = var.domain

  depends_on = [
    aws_ses_domain_identity.main
  ]

  # We ask DLUHC to make DNS records based on this
  lifecycle {
    prevent_destroy = true
  }
}

output "arn" {
  value = aws_ses_domain_identity.main.arn
}

output "required_validation_records" {
  value = concat(
    [
      {
        record_name  = "_amazonses.${var.domain}."
        record_type  = "TXT"
        record_value = aws_ses_domain_identity.main.verification_token
      },
      {
        record_name  = "${var.domain}."
        record_type  = "TXT"
        record_value = "v=spf1 include:amazonses.com ~all"
      },
      {
        record_name = "_dmarc.${var.domain}."
        record_type = "TXT"
        # TODO DT-159: We should add a reporting email (the "rua" field)
        # https://dmarc.org/2015/08/receiving-dmarc-reports-outside-your-domain/
        # And increase the pct
        record_value = "v=DMARC1;p=quarantine;pct=25"
      },
    ],
    [
      for token in aws_ses_domain_dkim.main.dkim_tokens : {
        record_name  = "${token}._domainkey.${var.domain}."
        record_type  = "CNAME"
        record_value = "${token}.dkim.amazonses.com"
      }
    ]
  )
}
