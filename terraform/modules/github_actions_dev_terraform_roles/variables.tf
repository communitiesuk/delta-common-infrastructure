variable "environment" {
  type        = string
  description = "test, staging or production"
}

variable "github_oidc_arn" {
  type        = string
  description = "the ARN of the OIDC provider used for GitHub Actions"
}
