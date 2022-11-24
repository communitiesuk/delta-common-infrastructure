# This user is used by the delta-marklogic-deploy repo's CI workflows
# One of a kind
# tfsec:ignore:aws-iam-no-user-attached-policies
resource "aws_iam_user" "marklogic_deploy_secret_reader" {
  name = "delta-marklogic-deploy-secret-reader-${var.environment}"
}

data "aws_secretsmanager_secret" "ml_admin_user" {
  name = "ml-admin-user-${var.environment}"
}

resource "aws_iam_policy" "read_marklogic_admin_password" {
  name   = "read-marklogic-admin-password-${var.environment}"
  policy = data.aws_iam_policy_document.read_marklogic_admin_password.json
}

data "aws_iam_policy_document" "read_marklogic_admin_password" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    effect    = "Allow"
    resources = [data.aws_secretsmanager_secret.ml_admin_user.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpc"
      values   = [var.vpc.id]
    }
  }
}

resource "aws_iam_user_policy_attachment" "read_marklogic_admin_password" {
  user       = aws_iam_user.marklogic_deploy_secret_reader.name
  policy_arn = aws_iam_policy.read_marklogic_admin_password.arn
}
