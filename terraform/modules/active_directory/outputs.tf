output "ad_management_server_ip" {
  value = aws_instance.ad_management_server.public_ip
}

output "ad_management_server_dns" {
  value = aws_instance.ad_management_server.public_dns
}

output "ad_management_server_password" {
  value = aws_instance.ad_management_server.password_data
}
