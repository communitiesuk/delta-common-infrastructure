# Create the Key Pair
resource "aws_key_pair" "ad_management_key_pair" {
  key_name   = "ad-management-key-pair"
  public_key = var.ad_management_public_key
}

resource "tls_private_key" "ca_server_ec2" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ca_server" {
  key_name   = "ca-server-ec2-key-${var.environment}"
  public_key = tls_private_key.ca_server_ec2.public_key_openssh
}