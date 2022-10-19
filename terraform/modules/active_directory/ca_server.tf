resource "aws_secretsmanager_secret_version" "ca_install_credentials" {
  secret_id = aws_secretsmanager_secret.ca_install_credentials.id
  secret_string = jsonencode({
    username = "Admin"
    password = random_password.directory_admin_password.result
  })
}

resource "aws_kms_key" "ad_secrets_key" {
  enable_key_rotation = true
}

resource "aws_secretsmanager_secret" "ca_install_credentials" {
  name       = "ldaps-ca-credentials-${var.environment}"
  kms_key_id = aws_kms_key.ad_secrets_key.arn
}

# Currently used to store a CRL, so encryption + logging + strictly private access are not required
# tfsec:ignore:aws-s3-enable-bucket-encryption tfsec:ignore:aws-s3-encryption-customer-key tfsec:ignore:aws-s3-enable-bucket-logging tfsec:ignore:aws-s3-block-public-acls tfsec:ignore:aws-s3-block-public-policy tfsec:ignore:aws-s3-ignore-public-acls tfsec:ignore:aws-s3-no-public-buckets tfsec:ignore:aws-s3-specify-public-access-block
resource "aws_s3_bucket" "ldaps_crl" {
  bucket = "data-collection-service-ldaps-crl-${var.environment}"
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "ldaps_crl" {
  bucket = aws_s3_bucket.ldaps_crl.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_cloudformation_stack" "ca_server" {
  name       = "ca-server-${var.environment}"
  on_failure = "DO_NOTHING"

  parameters = {
    # Network Configuration
    VPCCIDR           = var.vpc.cidr_block
    VPCID             = var.vpc.id
    EntCaServerSubnet = var.ldaps_ca_subnet.id
    DomainMembersSG   = aws_security_group.ad_management_server.id
    # Amazon EC2 Configuration
    KeyPairName            = aws_key_pair.ca_server.id
    AMI                    = "/aws/service/ami-windows-latest/Windows_Server-2019-English-Full-Base"
    EntCaServerNetBIOSName = "CASRV${var.environment}"
    # AD Domain Services Configuration
    DirectoryType       = "AWSManaged"
    DomainDNSName       = "dluhcdata.local"
    DomainNetBIOSName   = "DLUHCDATA"
    DomainController1IP = sort(aws_directory_service_directory.directory_service.dns_ip_addresses)[0]
    DomainController2IP = sort(aws_directory_service_directory.directory_service.dns_ip_addresses)[1]
    AdministratorSecret = aws_secretsmanager_secret.ca_install_credentials.arn
    SecretKMSKeyARN     = aws_kms_key.ad_secrets_key.arn
    # Certificate Services Configuration
    UseS3ForCRL     = "Yes"
    S3CRLBucketName = aws_s3_bucket.ldaps_crl.id
  }

  template_body      = file("${path.module}/one_tier_ca.yml")
  timeout_in_minutes = 60
  timeouts {
    create = "90m"
  }
  capabilities = ["CAPABILITY_IAM"]
}

data "aws_instance" "ca_server" {
  instance_id = aws_cloudformation_stack.ca_server.outputs["EntRootCAInstanceId"]
}
