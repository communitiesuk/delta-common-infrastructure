data "aws_kms_alias" "marklogic_backup" {
  name = "alias/ml-backups-${var.environment}"
}

# The backup script clears the workflow's OIDC credentials before creating S3 prefix markers.
# tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_policy" "backup_markers" {
  name        = "${local.name}-backup-markers"
  description = "Allow the MarkLogic backup script to create prefix markers in this environment"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = [for bucket in ["daily", "weekly"] : "arn:aws:s3:::dluhc-${bucket}-ml-backup-${var.environment}/*/"]
        Condition = {
          StringEquals = { "s3:ResourceAccount" = local.account_id }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey"]
        Resource = data.aws_kms_alias.marklogic_backup.target_key_arn
        Condition = {
          StringEquals = { "kms:ViaService" = "s3.${local.region}.amazonaws.com" }
        }
      },
    ]
  })
}
