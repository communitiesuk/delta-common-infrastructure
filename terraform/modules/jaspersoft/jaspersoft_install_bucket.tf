data "aws_s3_bucket" "jaspersoft_binaries" {
  bucket = var.jaspersoft_binaries_s3_bucket
}

data "aws_s3_object" "jaspersoft_install_zip" {
  bucket = data.aws_s3_bucket.jaspersoft_binaries.bucket
  key    = "js-7.8.1_hotfixed_2022-04-15.zip"
}
