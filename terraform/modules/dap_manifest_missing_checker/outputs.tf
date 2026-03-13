output "sns_topic_arn" {
  value = aws_sns_topic.dap_manifest_missing.arn
}
output "lambda_role_arn" {
  value = aws_iam_role.dap_manifest_missing_role.arn
}
