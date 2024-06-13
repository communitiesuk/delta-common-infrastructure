resource "aws_iam_role" "github_actions_delta_marklogic_deploy_secret_reader" {
  name               = "github-actions-delta-marklogic-deploy-secret-reader-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.github_actions_delta_marklogic_deploy_secret_reader_assume_role.json
}

data "aws_iam_policy_document" "github_actions_delta_marklogic_deploy_secret_reader_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.iam_github_openid_connect_provider_arn]
    }

    condition {
      test     = "StringEquals"
      values   = ["sts.amazonaws.com"]
      variable = "token.actions.githubusercontent.com:aud"
    }

    condition {
      test = "StringEquals"
      values = [
        "repo:communitiesuk/delta-marklogic-deploy:environment:${var.environment}"
      ]
      variable = "token.actions.githubusercontent.com:sub"
    }
  }
}

data "aws_iam_policy" "delta-marklogic-deploy-secret-reader" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/read-marklogic-admin-password-${var.environment}"
}

resource "aws_iam_role_policy_attachment" "github_actions_delta_marklogic_deploy_secret_reader" {
  role       = aws_iam_role.github_actions_delta_marklogic_deploy_secret_reader.name
  policy_arn = data.aws_iam_policy.delta-marklogic-deploy-secret-reader.arn
}
