output "ml_hostname" {
  value = aws_lb.ml_lb.dns_name
}

output "ml_ssh_private_key" {
  value     = tls_private_key.ml_ec2.private_key_openssh
  sensitive = true
}

output "deploy_user" {
  value = aws_iam_user.marklogic_deploy_secret_reader.name
}
