output "github_oidc_provider_arn" {
  description = "The ARN of the GitHub OpenID Connect provider"
  value       = aws_iam_openid_connect_provider.github.arn
}
