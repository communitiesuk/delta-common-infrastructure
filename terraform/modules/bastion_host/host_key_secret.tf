resource "aws_kms_key" "bastion_host_key_encryption_key" {
  description         = "${var.name_prefix}bastion-host-key-kms-key"
  enable_key_rotation = true
  tags                = merge(var.tags_default, var.tags_host_key)
}

resource "aws_secretsmanager_secret" "bastion_host_key" {
  name_prefix = "${var.name_prefix}bastion-ssh-host-key-"
  description = "SSH Host key for bastion"
  kms_key_id  = aws_kms_key.bastion_host_key_encryption_key.id
  tags        = merge(var.tags_default, var.tags_host_key)
}

resource "aws_secretsmanager_secret_version" "bastion_host_key" {
  secret_id     = aws_secretsmanager_secret.bastion_host_key.id
  secret_string = tls_private_key.bastion_host_key.private_key_openssh
}

resource "tls_private_key" "bastion_host_key" {
  algorithm = "ED25519"
}
