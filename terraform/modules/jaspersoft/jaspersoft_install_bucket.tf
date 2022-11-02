data "aws_s3_bucket" "jaspersoft_binaries" {
  bucket = "dluhc-jaspersoft-bin"
}

data "aws_s3_object" "jaspersoft_install_zip" {
  bucket = data.aws_s3_bucket.jaspersoft_binaries.bucket
  key    = "js-7.8.1_hotfixed_2022-04-15.zip"
}

locals {
  tomcat_systemd_service_file_templated = templatefile("${path.module}/install_files/tomcat.service", { JAVA_OPTS_MAX_HEAP = var.java_max_heap })
}

resource "aws_s3_object" "tomcat_systemd_service_file" {
  bucket  = data.aws_s3_bucket.jaspersoft_binaries.bucket
  key     = "${var.environment}/tomcat.service"
  content = local.tomcat_systemd_service_file_templated
  etag    = md5(local.tomcat_systemd_service_file_templated)
}

resource "aws_s3_object" "jaspersoft_config_file" {
  bucket = data.aws_s3_bucket.jaspersoft_binaries.bucket
  key    = "${var.environment}/default_master.properties"
  source = "${path.module}/install_files/default_master.properties"
  etag   = filemd5("${path.module}/install_files/default_master.properties")
}

resource "aws_s3_object" "jaspersoft_root_index_jsp" {
  bucket = data.aws_s3_bucket.jaspersoft_binaries.bucket
  key    = "${var.environment}/root_index.jsp"
  source = "${path.module}/install_files/root_index.jsp"
  etag   = filemd5("${path.module}/install_files/root_index.jsp")
}

resource "aws_s3_object" "jaspersoft_root_web_xml" {
  bucket = data.aws_s3_bucket.jaspersoft_binaries.bucket
  key    = "${var.environment}/root_web.xml"
  source = "${path.module}/install_files/root_web.xml"
  etag   = filemd5("${path.module}/install_files/root_web.xml")
}

locals {
  ldap_config_file_templated = templatefile(
    "${path.module}/install_files/applicationContext-externalAuth-LDAP.xml",
    { AD_DOMAIN = var.ad_domain }
  )
}

resource "aws_s3_object" "jaspersoft_ldap_config" {
  bucket  = data.aws_s3_bucket.jaspersoft_binaries.bucket
  key     = "${var.environment}/applicationContext-externalAuth-LDAP.xml"
  content = local.ldap_config_file_templated
  etag    = md5(local.ldap_config_file_templated)
}
