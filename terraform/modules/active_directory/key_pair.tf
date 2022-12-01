resource "tls_private_key" "ad_management_ec2" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ad_management_key_pair" {
  key_name   = "ad-management-ec2-key-${var.environment}"
  public_key = tls_private_key.ad_management_ec2.public_key_openssh
}

resource "tls_private_key" "ca_server_ec2" {
  count     = var.include_ca ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ca_server" {
  count      = var.include_ca ? 1 : 0
  key_name   = "ca-server-ec2-key-${var.environment}"
  public_key = tls_private_key.ca_server_ec2[0].public_key_openssh
}
