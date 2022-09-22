data "aws_s3_bucket" "jaspersoft_binaries" {
  bucket = "dluhc-jaspersoft-bin"
}

resource "aws_iam_instance_profile" "read_jaspersoft_binaries" {
  name = "${var.prefix}jaspersoft-s3-access"
  role = aws_iam_role.read_jaspersoft_binaries.name
}

resource "aws_iam_role" "read_jaspersoft_binaries" {
  name = "${var.prefix}jaspersoft-s3-access"
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

# Allowing access to a single bucket seems reasonable
# tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_role_policy" "read_jaspersoft_binaries" {
  name = "read_jaspersoft_binaries"
  role = aws_iam_role.read_jaspersoft_binaries.id

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

resource "aws_s3_object" "tomcat_systemd_service_file" {
  bucket = data.aws_s3_bucket.jaspersoft_binaries.bucket
  key    = "tomcat.service"
  source = "${path.module}/tomcat.service"
  etag   = filemd5("${path.module}/tomcat.service")
}

resource "aws_s3_object" "jaspersoft_config_file" {
  bucket = data.aws_s3_bucket.jaspersoft_binaries.bucket
  key    = "default_master.properties"
  source = "${path.module}/default_master.properties"
  etag   = filemd5("${path.module}/default_master.properties")
}
