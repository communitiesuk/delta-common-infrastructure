locals {
  is_development                      = var.environment == "test"
  github_actions_terraform_plan_name  = count.index == 1 ? aws_iam_role.github_actions_terraform_plan[0].name : null
  github_actions_terraform_admin_name = count.index == 1 ? aws_iam_role.github_actions_terraform_admin[0].name : null
}

resource "aws_iam_role" "github_actions_terraform_plan" {
  count              = local.is_development ? 1 : 0
  name               = "github-actions-terraform-ci-plan-read-only"
  assume_role_policy = data.aws_iam_policy_document.github_actions_terraform_plan_assume_role.json
}

resource "aws_iam_role" "github_actions_terraform_admin" {
  count              = local.is_development ? 1 : 0
  name               = "github-actions-terraform-admin"
  assume_role_policy = data.aws_iam_policy_document.github_actions_terraform_admin_assume_role.json
}
