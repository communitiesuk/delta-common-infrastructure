output "ad_management_server_private_ip" {
  value = aws_instance.ad_management_server.private_ip
}

output "ad_management_server_password" {
  value     = rsadecrypt(aws_instance.ad_management_server.password_data, tls_private_key.ad_management_ec2.private_key_pem)
  sensitive = true
}

output "ca_server_private_key" {
  value     = tls_private_key.ca_server_ec2.private_key_pem
  sensitive = true
}

output "directory_admin_password" {
  value     = random_password.directory_admin_password.result
  sensitive = true
}

output "dns_servers" {
  value       = aws_directory_service_directory.directory_service.dns_ip_addresses
  description = "IP addresses of the managed AD's DNS servers"
}
