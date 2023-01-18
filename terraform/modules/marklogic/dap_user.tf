# One of a kind
# tfsec:ignore:aws-iam-no-user-attached-policies
resource "aws_iam_user" "dap" {
  name = "dap-export-reader-${var.environment}"
}

resource "aws_iam_user_policy_attachment" "dap" {
  user       = aws_iam_user.dap.name
  policy_arn = aws_iam_policy.dap.arn
}

resource "aws_iam_policy" "dap" {
  name   = "tf-state-read-only"
  policy = data.aws_iam_policy_document.dap.json
}

# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "dap" {
  statement {
    sid = "s3"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]
    resources = [
      module.dap_export_bucket.bucket_arn,
      "${module.dap_export_bucket.bucket_arn}/*",
    ]
  }

  statement {
    sid = "kms"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [aws_kms_key.dap_export.arn]
  }
}
