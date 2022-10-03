output "cloudfront_domains_certificate_arn" {
  value = aws_acm_certificate.cloudfront_domains_wildcard.arn
}

output "delegated_zone_id" {
  value = aws_route53_zone.delegated_zone.zone_id
}

output "cloudfront_domains_certificate_required_validation_records" {
  value = local.non_delegated_validations
}
