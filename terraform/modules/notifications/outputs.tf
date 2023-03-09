output "alarms_sns_topic_arn" {
  value = aws_sns_topic.alarm_sns_topic.arn
}

output "alarms_sns_topic_global_arn" {
  value = aws_sns_topic.alarm_sns_topic_global.arn
}

output "security_sns_topic_arn" {
  value = aws_sns_topic.security_sns_topic.arn
}

output "security_sns_topic_global_arn" {
  value = aws_sns_topic.security_sns_topic_global.arn
}
