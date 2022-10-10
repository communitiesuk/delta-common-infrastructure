output "domain" {
  value       = aws_codeartifact_domain.codeartifact_domain.domain
  description = "The domain of the created Code Artifact domain"
}
