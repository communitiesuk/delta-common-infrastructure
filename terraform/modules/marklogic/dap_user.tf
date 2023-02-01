# One of a kind
# tfsec:ignore:aws-iam-no-user-attached-policies
resource "aws_iam_user" "dap" {
  name = "dap-export-reader-${var.environment}"
  lifecycle {
    # We manually create credentials and provide them to the DAP team. So let's not accidentally destroy this user
    prevent_destroy = true
  }
}

resource "aws_iam_user_policy_attachment" "dap" {
  user       = aws_iam_user.dap.name
  policy_arn = aws_iam_policy.dap.arn
}

resource "aws_iam_policy" "dap" {
  name   = "dap-export-reader-${var.environment}"
  policy = data.aws_iam_policy_document.dap.json
}

# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "dap" {
  statement {
    sid = "s3"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketLocation"
    ]
    resources = [
      module.dap_export_bucket.bucket_arn,
      "${module.dap_export_bucket.bucket_arn}/latest/*",
    ]
    # condition {
    #   test     = "IpAddress"
    #   variable = "aws:SourceIp"
    #   values   = ["52.17.138.171/32"]
    # }
  }
}
