output "ml_hostname" {
  value = module.marklogic.ml_hostname
}

output "ml_hostname_dns" {
  description = "DNS hostname for MarkLogic cluster (marklogic1.vpc.local)"
  value       = aws_route53_record.marklogic1_internal_nlb.fqdn
}

output "ml_ssh_private_key" {
  value     = module.marklogic.ml_ssh_private_key
  sensitive = true
}

output "ml_http_target_group_arn" {
  value = module.marklogic.ml_http_target_group_arn
}

output "vpc_id" {
  value = data.aws_vpc.staging.id
}

output "private_dns" {
  value = {
    zone_id     = data.aws_route53_zone.private.zone_id
    base_domain = data.aws_route53_zone.private.name
  }
}

output "alarms_sns_topic_arn" {
  value = module.notifications.alarms_sns_topic_arn
}

output "alarms_sns_topic_global_arn" {
  value = module.notifications.alarms_sns_topic_global_arn
}

output "security_sns_topic_arn" {
  value = module.notifications.security_sns_topic_arn
}

output "security_sns_topic_global_arn" {
  value = module.notifications.security_sns_topic_global_arn
}

output "deploy_user_kms_key_arn" {
  value = module.marklogic.deploy_user_kms_key_arn
}

output "session_manager_policy_arn" {
  value = local.session_manager_policy_arn
}
