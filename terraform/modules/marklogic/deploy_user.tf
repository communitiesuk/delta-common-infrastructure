# This user is used by the delta-marklogic-deploy repo's CI workflows
# One of a kind
# tfsec:ignore:aws-iam-no-user-attached-policies
resource "aws_iam_user" "marklogic_deploy_secret_reader" {
  name = "delta-marklogic-deploy-secret-reader-${var.environment}"
}

resource "aws_kms_key" "ml_deploy_secrets" {
  description         = "delta-marklogic-deploy-secrets-${var.environment}"
  enable_key_rotation = true
}

resource "aws_kms_alias" "ml_deploy_secrets" {
  name          = "alias/delta-marklogic-deploy-secrets-${var.environment}"
  target_key_id = aws_kms_key.ml_deploy_secrets.key_id
}

data "aws_secretsmanager_secret" "ml_admin_user" {
  name = "ml-admin-user-${var.environment}"

  lifecycle {
    postcondition {
      condition     = lookup(self.tags, "delta-marklogic-deploy-read", null) == var.environment
      error_message = "The 'delta-marklogic-deploy-read' tag must be set equal to the environment name, so that this secret can be read by the MarkLogic deploy jobs"
    }
  }
}

resource "aws_iam_policy" "read_marklogic_deploy_secrets" {
  name   = "read-marklogic-admin-password-${var.environment}"
  policy = data.aws_iam_policy_document.read_marklogic_deploy_secrets.json
}

# Tag based access control
# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "read_marklogic_deploy_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    effect    = "Allow"
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/delta-marklogic-deploy-read"
      values   = [var.environment]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpc"
      values   = [var.vpc.id]
    }
  }
  statement {
    actions   = ["kms:DescribeKey", "kms:Decrypt"]
    effect    = "Allow"
    resources = [aws_kms_key.ml_deploy_secrets.arn]
  }
}

resource "aws_iam_user_policy_attachment" "read_marklogic_deploy_secrets" {
  user       = aws_iam_user.marklogic_deploy_secret_reader.name
  policy_arn = aws_iam_policy.read_marklogic_deploy_secrets.arn
}
