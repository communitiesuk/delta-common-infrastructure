output "ad_management_server_ip" {
  value = aws_instance.ad_management_server.public_ip
}

output "ad_management_server_dns" {
  value = aws_instance.ad_management_server.public_dns
}

output "ad_management_server_password" {
  value = aws_instance.ad_management_server.password_data
}

output "ca_server_private_key" {
  value     = tls_private_key.ca_server_ec2.private_key_pem
  sensitive = true
}

output "ad_management_private_key" {
  value     = tls_private_key.ad_management_ec2.private_key_pem
  sensitive = true
}

output "directory_admin_password" {
  value     = random_password.directory_admin_password.result
  sensitive = true
}
