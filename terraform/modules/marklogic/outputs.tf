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

output "deploy_user_cpm_kms_key_arn" {
  value = aws_kms_key.cpm_ml_deploy_secrets.arn
}

output "deploy_user_delta_kms_key_arn" {
  value = aws_kms_key.delta_ml_deploy_secrets.arn
}

output "instance_iam_role" {
  value = aws_iam_role.ml_iam_role.name
}

output "ml_http_target_group_arn" {
  value = aws_lb_target_group.ml_http.arn
}

output "backup_key" {
  value = aws_kms_key.ml_backup_bucket_key.arn
}

output "daily_backup_bucket_arn" {
  value = module.daily_backup_bucket.bucket_arn
}

output "weekly_backup_bucket_arn" {
  value = module.weekly_backup_bucket.bucket_arn
}
