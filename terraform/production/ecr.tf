# tfsec:ignore:aws-iam-no-user-attached-policies
resource "aws_iam_user" "cpm_ci" {
  name = "cpm-ci"
}

# tfsec:ignore:aws-iam-no-user-attached-policies
resource "aws_iam_user" "delta_ci" {
  name = "delta_ci"
}

resource "aws_iam_access_key" "cpm_ci" {
  user = aws_iam_user.cpm_ci.name
}

resource "aws_iam_access_key" "delta_ci" {
  user = aws_iam_user.delta_ci.name
}

locals {
  repositories = {
    "cpm" = {
      repo_name = "cpm",
      push_user = aws_iam_user.cpm_ci.name
    },
    "delta_api" = {
      repo_name = "delta_api",
      push_user = aws_iam_user.delta_ci.name
    },
    "delta_internal" = {
      repo_name = "delta_internal",
      push_user = aws_iam_user.delta_ci.name
    },
    "delta_fo_to_pdf" = {
      repo_name = "delta_fo_to_pdf",
      push_user = aws_iam_user.delta_ci.name
    }
  }
}

module "ecr" {
  for_each = local.repositories
  source   = "../modules/ecr_repository"

  repo_name = each.value["repo_name"]
  push_user = each.value["push_user"]
}
