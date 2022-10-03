resource "tls_private_key" "ml_ec2" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ml_key_pair" {
  key_name   = "ml-ec2-key-${var.environment}"
  public_key = tls_private_key.ml_ec2.public_key_openssh
}
