output "domain" {
  value       = aws_codeartifact_domain.codeartifact_domain.domain
  description = "The domain of the created Code Artifact domain"
}

output "access_policy" {
  value       = data.aws_iam_policy_document.codeartifact_access
  description = "Policy allowing generation of authorization token for codeartifact domain"
}
