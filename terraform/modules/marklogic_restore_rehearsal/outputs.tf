output "ml_hostname" {
  value = aws_lb.ml_lb.dns_name
}

output "ml_ssh_private_key" {
  value     = tls_private_key.ml_ec2.private_key_openssh
  sensitive = true
}

output "instance_iam_role" {
  value = aws_iam_role.ml_iam_role.name
}

output "ml_http_target_group_arn" {
  value = aws_lb_target_group.ml_http.arn
}
