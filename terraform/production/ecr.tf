# Only required for production. The test/staging environments share produciton's build artifacts.

# This user is used by the common-payments-module repo's CI workflows
# One of a kind
# tfsec:ignore:aws-iam-no-user-attached-policies
resource "aws_iam_user" "cpm_ci" {
  name = "cpm-ci"
}

resource "aws_iam_access_key" "cpm_ci" {
  user = aws_iam_user.cpm_ci.name
}

# This user is used by the delta repository and managed there too
data "aws_iam_user" "delta_ci" {
  user_name = "delta_ci"
}

locals {
  repositories = {
    "cpm" = {
      repo_name = "cpm",
      push_user = aws_iam_user.cpm_ci.name
    },
    "delta_api" = {
      repo_name = "delta-api",
      push_user = data.aws_iam_user.delta_ci.user_name
    },
    "delta_internal" = {
      repo_name = "delta-internal",
      push_user = data.aws_iam_user.delta_ci.user_name
    },
    "delta_fo_to_pdf" = {
      repo_name = "delta-fo-to-pdf",
      push_user = data.aws_iam_user.delta_ci.user_name
    },
    "keycloak" = {
      repo_name = "keycloak",
      push_user = data.aws_iam_user.delta_ci.user_name
    }
  }
}

module "ecr" {
  for_each  = local.repositories
  source    = "../modules/ecr_repository"
  kms_alias = "alias/${each.key}-ecr"
  repo_name = each.value["repo_name"]
  push_user = each.value["push_user"]
}
