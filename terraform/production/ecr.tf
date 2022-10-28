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
  repositories = [{
    repo_name = "cpm",
    push_user = aws_iam_user.cpm_ci.name
    }, {
    repo_name = "delta_api",
    push_user = aws_iam_user.delta_ci.name
    }, {
    repo_name = "delta_internal",
    push_user = aws_iam_user.delta_ci.name
    }, {
    repo_name = "delta_fo_to_pdf",
    push_user = aws_iam_user.delta_ci.name
  }]
}

module "ecr" {
  count  = length(local.repositories)
  source = "../modules/ecr_repository"

  repo_name = local.repositories[count.index]["repo_name"]
  push_user = local.repositories[count.index]["push_user"]
}
