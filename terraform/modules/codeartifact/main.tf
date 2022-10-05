resource "aws_kms_key" "codeartifact" {
  description         = "Codeartifact encryption key"
  enable_key_rotation = true
}

resource "aws_codeartifact_domain" "codeartifact_domain" {
  domain         = var.codeartifact_domain_name
  encryption_key = aws_kms_key.codeartifact.arn
}

# Policy allow generation of authorization token for codeartifact
data "aws_iam_policy_document" "codeartifact_access" {
  statement {
    effect  = "Allow",
    actions = [
      "codeartifact:GetAuthorizationToken"
    ]
    resources = [aws_codeartifact_domain.codeartifact_domain.arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["sts:GetServiceBearerToken"]
    resources = ["*"]
    condition = {
      test     = "StringEquals"
      variable = "sts:AWSServiceName"
      values   = [
        "codeartifact.amazonaws.com"
      ]
    }
  }
}
