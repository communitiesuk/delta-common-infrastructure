# JasperReports Server

Requires S3 bucket (var.jaspersoft_binaries_s3_bucket) in the current AWS account with JasperReports Server binaries in, currently expects 7.8.0 and the 7.8.1 Service Pack.

```sh
aws s3api create-bucket --bucket dluhc-jaspersoft-bin --acl private --region eu-west-1 --create-bucket-configuration LocationConstraint=eu-west-1
aws s3api put-bucket-versioning --bucket dluhc-jaspersoft-bin --versioning-configuration Status=Enabled
aws s3 cp TIB_js-jrs-cp_7.8.0_bin.zip s3://dluhc-jaspersoft-bin
aws s3 cp TIB_js-jrs_cp_7.8.1_sp.zip s3://dluhc-jaspersoft-bin
```
