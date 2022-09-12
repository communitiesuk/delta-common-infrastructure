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
  name = "ldaps_ca_credentials-${var.environment}"
  kms_key_id = aws_kms_key.ad_secrets_key.arn
}

# Currenly used to store a CRL, so encryption + logging are not required
# tfsec:ignore:aws-s3-enable-bucket-encryption tfsec:ignore:aws-s3-encryption-customer-key tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "ldaps_crl_and_certs" {
  bucket = "data-collection-service-ldaps-crl-certs-${var.environment}"
  lifecycle {
    prevent_destroy = true
  }
  tags = var.default_tags
}

resource "aws_s3_bucket_versioning" "ldaps_crl_and_certs" {
  bucket = aws_s3_bucket.ldaps_crl_and_certs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "ldaps_crl_and_certs" {
  bucket = aws_s3_bucket.ldaps_crl_and_certs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudformation_stack" "ca_server" {
  name = "ca-server-${var.environment}"

  parameters = {
    # Network Configuration
    VPCCIDR           = var.vpc.cidr_block
    VPCID             = var.vpc.id
    EntCaServerSubnet = var.ldaps_ca_subnet.id
    DomainMembersSG   = aws_security_group.ad_management_server.id
    # Amazon EC2 Configuration
    KeyPairName = aws_key_pair.ca_server.id
    AMI         = "/aws/service/ami-windows-latest/Windows_Server-2019-English-Full-Base"
    # AD Domain Services Configuration
    DirectoryType       = "AWSManaged"
    DomainDNSName       = "dluhcdata.local"
    DomainNetBIOSName   = "DLUHCDATA"
    DomainController1IP = sort(aws_directory_service_directory.directory_service.dns_ip_addresses)[0]
    DomainController2IP = sort(aws_directory_service_directory.directory_service.dns_ip_addresses)[1]
    AdministratorSecret = aws_secretsmanager_secret.ca_install_credentials.arn
    # Certificate Services Configuration
    UseS3ForCRL     = "Yes"
    S3CRLBucketName = aws_s3_bucket.ldaps_crl_and_certs.id
  }

  template_body      = file("${path.module}/one_tier_ca.yml")
  timeout_in_minutes = 60
  timeouts {
    create = "60m"
  }
  capabilities = ["CAPABILITY_IAM"]
}

data "aws_instance" "ca_server" {
  instance_id = aws_cloudformation_stack.ca_server.outputs["EntRootCAInstanceId"]
}