resource "aws_secretsmanager_secret_version" "ca_install_credentials" {
  secret_id = aws_secretsmanager_secret.ca_install_credentials.id
  secret_string = jsonencode({
    username = "Admin"
    password = random_password.directory_admin_password.result
  })
}

resource "aws_kms_key" "ad_secrets_key" {
  enable_key_rotation = true
  description         = "ad-secrets-key-${var.environment}"
  tags                = { "terraform-plan-read" = true }
}

resource "aws_kms_alias" "ad_secrets_key" {
  name          = "alias/ad-secrets-key-${var.environment}"
  target_key_id = aws_kms_key.ad_secrets_key.key_id
}

resource "aws_secretsmanager_secret" "ca_install_credentials" {
  name                    = "tf-ldaps-ca-credentials-${var.environment}"
  description             = "Managed by Terraform, do not update manually"
  kms_key_id              = aws_kms_key.ad_secrets_key.arn
  recovery_window_in_days = 0
  tags                    = { "terraform-plan-read" = true }
}

# Currently used to store a CRL, so KMS + logging + strictly private access are not required
# tfsec:ignore:aws-s3-enable-bucket-logging tfsec:ignore:aws-s3-block-public-acls tfsec:ignore:aws-s3-block-public-policy tfsec:ignore:aws-s3-ignore-public-acls tfsec:ignore:aws-s3-no-public-buckets tfsec:ignore:aws-s3-specify-public-access-block
resource "aws_s3_bucket" "ldaps_crl" {
  bucket = "data-collection-service-ldaps-crl-${var.environment}"
}

# tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "ldaps_crl" {
  bucket = aws_s3_bucket.ldaps_crl.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "ldaps_crl" {
  bucket = aws_s3_bucket.ldaps_crl.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_cloudformation_stack" "ca_server" {
  count      = var.include_ca ? 1 : 0
  name       = "ca-server-${var.environment}"
  on_failure = "DO_NOTHING"

  parameters = {
    # Network Configuration
    VPCCIDR           = var.vpc.cidr_block
    VPCID             = var.vpc.id
    EntCaServerSubnet = var.ldaps_ca_subnet.id
    DomainMembersSG   = aws_security_group.ad_management_server.id
    # Amazon EC2 Configuration
    KeyPairName = aws_key_pair.ca_server[0].id
    AMI         = "/aws/service/ami-windows-latest/Windows_Server-2019-English-Full-Base"
    # AD Domain Services Configuration
    DirectoryType       = "AWSManaged"
    DomainDNSName       = aws_directory_service_directory.directory_service.name
    DomainNetBIOSName   = var.ad_netbios_name
    DomainController1IP = sort(aws_directory_service_directory.directory_service.dns_ip_addresses)[0]
    DomainController2IP = sort(aws_directory_service_directory.directory_service.dns_ip_addresses)[1]
    AdministratorSecret = aws_secretsmanager_secret.ca_install_credentials.arn
    SecretKMSKeyARN     = aws_kms_key.ad_secrets_key.arn
    # Certificate Services Configuration
    UseS3ForCRL              = "Yes"
    S3CRLBucketName          = aws_s3_bucket.ldaps_crl.id
    EntCaValidityPeriodUnits = var.ent_ca_validity_years
    # The test environment's CA server had to be rebuilt with a new name
    EntCaServerNetBIOSName = "CASRV${var.environment == "test" ? "test4" : var.environment}"
  }

  template_body      = file("${path.module}/one_tier_ca.yml")
  timeout_in_minutes = 60
  timeouts {
    create = "90m"
  }
  capabilities = ["CAPABILITY_IAM"]
  lifecycle {
    ignore_changes = [template_body]
  }
}

data "aws_instance" "ca_server" {
  count       = var.include_ca ? 1 : 0
  instance_id = var.include_ca ? try(aws_cloudformation_stack.ca_server[0].outputs["EntRootCAInstanceId"], "") : ""
}
