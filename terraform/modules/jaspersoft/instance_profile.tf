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

resource "aws_iam_role_policy" "read_jaspersoft_ldap_password" {
  name = "${var.prefix}read-jaspersoft-ldap-password"
  role = aws_iam_role.jasperserver.id

  policy = data.aws_iam_policy_document.read_jaspersoft_ldap_password.json
}

data "aws_iam_policy_document" "read_jaspersoft_ldap_password" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    effect    = "Allow"
    resources = [data.aws_secretsmanager_secret.ldap_bind_password.arn]
  }
}

# Allowing access to a single bucket seems reasonable
# tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_role_policy" "read_jaspersoft_binaries" {
  name = "${var.prefix}read-jaspersoft-binaries"
  role = aws_iam_role.jasperserver.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Resource": "${data.aws_s3_bucket.jaspersoft_binaries.arn}/*"
    }
  ]
}
EOF
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
    resources = ["${aws_cloudwatch_log_group.jasper_patch.arn}:*"]
  }
}

resource "aws_iam_role_policy" "jasper_cloudwatch" {
  name   = "${var.prefix}jaspersoft-cloudwatch"
  role   = aws_iam_role.jasperserver.id
  policy = data.aws_iam_policy_document.jasper_cloudwatch.json
}
