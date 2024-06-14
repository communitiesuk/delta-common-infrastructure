data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]
  # Mixed information about the requirement for a thumbprint and its value but based on this post: https://github.blog/changelog/2023-06-27-github-actions-update-on-oidc-integration-with-aws/ have added the values below.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
    "1b511abead59c6ce207077c0bf0e0043b1382612"
  ]
}
