data "aws_s3_bucket" "jaspersoft_binaries" {
  bucket = "dluhc-jaspersoft-bin"
}

data "aws_s3_object" "jaspersoft_install_zip" {
  bucket = data.aws_s3_bucket.jaspersoft_binaries.bucket
  key    = "js-7.8.1_hotfixed_2022-04-15.zip"
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
  name = "${var.prefix}read-jaspersoft-binaries"
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

locals {
  tomcat_systemd_service_file_templated = templatefile("${path.module}/install_files/tomcat.service", { JAVA_OPTS_MAX_HEAP = var.java_max_heap })
}

resource "aws_s3_object" "tomcat_systemd_service_file" {
  bucket  = data.aws_s3_bucket.jaspersoft_binaries.bucket
  key     = "tomcat.service"
  content = local.tomcat_systemd_service_file_templated
  etag    = md5(local.tomcat_systemd_service_file_templated)
  tags   = { environment = "shared" }
}

resource "aws_s3_object" "jaspersoft_config_file" {
  bucket = data.aws_s3_bucket.jaspersoft_binaries.bucket
  key    = "default_master.properties"
  source = "${path.module}/install_files/default_master.properties"
  etag   = filemd5("${path.module}/install_files/default_master.properties")
  tags   = { environment = "shared" }
}

resource "aws_s3_object" "jaspersoft_root_index_jsp" {
  bucket = data.aws_s3_bucket.jaspersoft_binaries.bucket
  key    = "root_index.jsp"
  source = "${path.module}/install_files/root_index.jsp"
  etag   = filemd5("${path.module}/install_files/root_index.jsp")
  tags   = { environment = "shared" }
}

resource "aws_s3_object" "jaspersoft_root_web_xml" {
  bucket = data.aws_s3_bucket.jaspersoft_binaries.bucket
  key    = "root_web.xml"
  source = "${path.module}/install_files/root_web.xml"
  etag   = filemd5("${path.module}/install_files/root_web.xml")
  tags   = { environment = "shared" }
}
