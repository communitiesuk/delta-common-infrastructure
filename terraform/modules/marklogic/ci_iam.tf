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

resource "aws_iam_role_policy_attachment" "github_actions_delta_marklogic_deploy_secret_reader" {
  role       = aws_iam_role.github_actions_delta_marklogic_deploy_secret_reader.name
  policy_arn = aws_iam_policy.read_marklogic_deploy_secrets.arn
}

# MLCP import filenames are dynamic, so restrict access to a dedicated prefix.
# tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_role_policy" "github_actions_mlcp_import" {
  name = "marklogic-csv-import"
  role = aws_iam_role.github_actions_delta_marklogic_deploy_secret_reader.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:GetObjectVersion"]
      Resource = "${module.config_files_bucket.bucket_arn}/mlcp-imports/*"
    }]
  })
}
