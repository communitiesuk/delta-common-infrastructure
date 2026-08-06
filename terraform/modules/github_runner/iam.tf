resource "aws_iam_role" "runner" {
  name               = "runner-role-${var.environment}"
  assume_role_policy = templatefile("${path.module}/policies/instance_role_trust_policy.json", {})
  path               = "/gh-runner-${var.environment}/"
}

resource "aws_iam_instance_profile" "runner" {
  name = "runner-profile-${var.environment}"
  role = aws_iam_role.runner.name
  path = "/gh-runner-${var.environment}/"
}

resource "aws_iam_role_policy" "get_ssm_parameters" {
  name = "runner-ssm-parameters"
  role = aws_iam_role.runner.name
  policy = templatefile("${path.module}/policies/instance_ssm_parameters_policy.json",
    {
      arn = aws_ssm_parameter.cloudwatch_agent_config_runner.arn
    }
  )
}

locals {
  runner_iam_role_managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
}

resource "aws_iam_role_policy_attachment" "managed_policies" {
  count      = length(local.runner_iam_role_managed_policy_arns)
  role       = aws_iam_role.runner.name
  policy_arn = element(local.runner_iam_role_managed_policy_arns, count.index)
}

resource "aws_iam_role_policy_attachment" "extra_attach" {
  role       = aws_iam_role.runner.name
  policy_arn = var.extra_instance_policy_arn
}

resource "aws_iam_role_policy_attachment" "s3_backups" {
  role       = aws_iam_role.runner.name
  policy_arn = aws_iam_policy.s3_backups.arn
}

resource "aws_iam_policy" "s3_backups" {
  name        = "runner-s3-backups-${var.environment}"
  description = "Allows the GitHub runner to read and write MarkLogic S3 backup buckets"

  policy = data.aws_iam_policy_document.s3_backups.json
}

#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "s3_backups" {
  statement {
    actions = [
      "s3:GetEncryptionConfiguration",
      "s3:GetObject",
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
    ]
    effect = "Allow"
    resources = [
      var.daily_backup_bucket_arn,
      "${var.daily_backup_bucket_arn}/*",
      var.weekly_backup_bucket_arn,
      "${var.weekly_backup_bucket_arn}/*",
    ]
  }

  statement {
    actions = [
      "s3:GetEncryptionConfiguration",
      "s3:GetObject",
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    effect = "Allow"
    resources = [
      var.locked_backup_replication_bucket_arn,
      "${var.locked_backup_replication_bucket_arn}/*",
    ]
  }

  statement {
    actions   = ["kms:GenerateDataKey", "kms:DescribeKey", "kms:Decrypt"]
    effect    = "Allow"
    resources = [var.backup_key_arn]
  }
}
