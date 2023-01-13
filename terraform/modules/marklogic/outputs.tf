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

output "deploy_user_kms_key_arn" {
  value = aws_kms_key.ml_deploy_secrets.arn
}

output "instance_iam_role" {
  value = aws_iam_role.ml_iam_role.name
}

output "ml_8050_target_group" {
  value = aws_lb_target_group.ml["8050"]
}
