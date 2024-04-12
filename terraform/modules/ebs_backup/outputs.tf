output "role_arn" {
  value = aws_iam_role.ebs_backup.arn
}

output "sns_topic_arn" {
  value = aws_sns_topic.ebs_backup_completed.arn
}
