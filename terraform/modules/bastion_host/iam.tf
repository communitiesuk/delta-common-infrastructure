data "aws_iam_policy_document" "bastion_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
    effect = "Allow"
  }
}

resource "aws_iam_role" "bastion" {
  name_prefix        = "${var.name_prefix}bastion"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume_role.json
}

data "aws_iam_policy_document" "bastion_policy" {
  # Allow downloading of user SSH public keys
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.ssh_keys.arn}/*"]
    effect    = "Allow"
  }

  # Allow listing SSH public keys
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.ssh_keys.arn]
  }

  # Allow reading the host key secret
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.bastion_host_key.arn]
  }

  # Allow use of the KMS key used to encrypt the host key secret
  statement {
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.bastion_host_key_encryption_key.arn]
  }
}

resource "aws_iam_policy" "bastion" {
  name_prefix = "${var.name_prefix}bastion"
  policy      = data.aws_iam_policy_document.bastion_policy.json
}

resource "aws_iam_role_policy_attachment" "bastion_policy" {
  role       = aws_iam_role.bastion.name
  policy_arn = aws_iam_policy.bastion.arn
}

data "aws_iam_policy" "cloudwatch_agent" {
  arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  count      = var.log_group_name == null ? 0 : 1
  role       = aws_iam_role.bastion.name
  policy_arn = data.aws_iam_policy.cloudwatch_agent.arn
}

resource "aws_iam_instance_profile" "bastion_host_profile" {
  name_prefix = "${var.name_prefix}bastion-profile"
  role        = aws_iam_role.bastion.name
}
