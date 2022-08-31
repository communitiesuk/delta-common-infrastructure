resource "aws_secretsmanager_secret_version" "ca_install_credentials" {
  secret_id = aws_secretsmanager_secret.ca_install_credentials.id
  secret_string = jsonencode({
    username = "Admin"
    password = var.ca_password
  })
}

resource "aws_secretsmanager_secret" "ca_install_credentials" {
  name = "ldaps_ca_credentials"
}

resource "aws_s3_bucket" "ldaps_crl_and_certs" {
  bucket = "data-collection-service-ldaps-crl-certs-${var.environment}"
  lifecycle {
    prevent_destroy = true
  }
}

# resource "aws_cloudformation_stack" "ca_server" {
#   name = "ca-server"

#   parameters = {
#     # Network Configuration
#     VPCCIDR = var.vpc.cidr_block
#     VPCID = var.vpc.id
#     CaServerSubnet = var.ldaps_ca_subnet.id
#     DomainMembersSG = aws_security_group.ad_management_server.id
#     # Amazon EC2 Configuration
#     KeyPairName = aws_key_pair.ca_server.id
#     AMI = "/aws/service/ami-windows-latest/Windows_Server-2019-English-Full-Base"
#     # AD Domain Services Configuration
#     DirectoryType = "AWSManaged"
#     DomainDNSName = "dluhcdata.local"
#     DomainNetBIOSName = "DLUHCDATA"
#     DomainController1IP = sort(aws_directory_service_directory.directory_service.dns_ip_addresses)[0]
#     DomainController2IP = sort(aws_directory_service_directory.directory_service.dns_ip_addresses)[1]
#     AdministratorSecret = aws_secretsmanager_secret.ca_install_credentials.arn
#     # Certificate Services Configuration
#     CADeploymentType = "One-Tier"
#     UseS3ForCRL = "Yes"
#     S3CRLBucketName = aws_s3_bucket.ldaps_crl_and_certs.id
#   }

#   template_body = file("${path.module}/pki_cf_template.yml")

#   capabilities = ["CAPABILITY_IAM"]
# }

resource "aws_cloudformation_stack" "ca_server" {
  name = "ca-server"

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