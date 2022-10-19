output "domain" {
  value       = aws_codeartifact_domain.codeartifact_domain.domain
  description = "The domain of the created Code Artifact domain"
}

output "domain_arn" {
  value       = aws_codeartifact_domain.codeartifact_domain.arn
  description = "The arn of the created Code Artifact domain"
}
