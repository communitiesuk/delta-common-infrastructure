resource "aws_iam_instance_profile" "jasperserver" {
  name = "${var.prefix}jaspersoft-server-profile"
  role = aws_iam_role.jasperserver.name
}

resource "aws_iam_role" "jasperserver" {
  name = "${var.prefix}jaspersoft-server-role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "read_secrets" {
  name = "${var.prefix}read-jaspersoft-secrets"
  role = aws_iam_role.jasperserver.id

  policy = data.aws_iam_policy_document.read_secrets.json
}

data "aws_iam_policy_document" "read_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    effect  = "Allow"
    resources = [
      aws_secretsmanager_secret.jaspersoft_db_password.arn
    ]
  }
}

# Allowing access to a single bucket seems reasonable
# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "access_buckets" {
  statement {
    sid       = "InstallBucket"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = ["${data.aws_s3_bucket.jaspersoft_binaries.arn}/*"]
  }
  statement {
    sid       = "ConfigBucket"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
    resources = ["${module.config_bucket.bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "access_buckets" {
  name   = "${var.prefix}read-jaspersoft-binaries"
  role   = aws_iam_role.jasperserver.id
  policy = data.aws_iam_policy_document.access_buckets.json
}

# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "jasper_cloudwatch" {
  statement {
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = concat(
      ["${aws_cloudwatch_log_group.jasper_patch.arn}:*"],
    [for arn in module.jaspersoft_log_group.log_group_arns : "${arn}:*"])
  }

  statement {
    actions = [
      "cloudwatch:PutMetricData",
      "ec2:DescribeVolumes",
      "ec2:DescribeTags"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "jasper_cloudwatch" {
  name   = "${var.prefix}jaspersoft-cloudwatch"
  role   = aws_iam_role.jasperserver.id
  policy = data.aws_iam_policy_document.jasper_cloudwatch.json
}

data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "jasper_ssm" {
  role       = aws_iam_role.jasperserver.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}

resource "aws_iam_role_policy_attachment" "extra_attach" {
  role       = aws_iam_role.jasperserver.name
  policy_arn = var.extra_instance_policy_arn
}
