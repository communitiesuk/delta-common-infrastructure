output "ml_hostname" {
  value = aws_lb.ml_lb.dns_name
}

output "ml_ssh_private_key" {
  value = tls_private_key.ml_ec2.private_key_openssh
  sensitive = true
}