output "github_oidc_provider_arn" {
  description = "The ARN of the GitHub OpenID Connect provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_terraform_plan_name" {
  value = local.github_actions_terraform_plan_name
}

output "github_actions_terraform_admin_name" {
  value = local.github_actions_terraform_admin_name
}
