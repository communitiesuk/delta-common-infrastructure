output "jaspersoft_alb_domain" {
  value = aws_lb.main.dns_name
}

output "instance_private_ip" {
  value = aws_instance.jaspersoft_server.private_ip
}
