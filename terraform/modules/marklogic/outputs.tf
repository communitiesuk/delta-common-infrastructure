output "ml_url" {
  value = aws_cloudformation_stack.marklogic.outputs["URL"]
}

output "ml_ssh_private_key" {
  value = tls_private_key.ml_ec2.private_key_openssh
  sensitive = true
}