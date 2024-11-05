# TODO Remove once no longer referenced by delta repo
output "delta_internal_subnet_ids" {
  value = module.networking.delta_fo_to_pdf_subnets[*].id
}

output "delta_fo_to_pdf_subnet_ids" {
  value = module.networking.delta_fo_to_pdf_subnets[*].id
}

output "delta_api_subnet_ids" {
  value = module.networking.delta_api_subnets[*].id
}

output "delta_website_subnet_ids" {
  value = module.networking.delta_website_subnets[*].id
}

output "public_subnet_ids" {
  value = module.networking.public_subnets[*].id
}

output "cpm_private_subnet_ids" {
  value = module.networking.cpm_private_subnets[*].id
}

// TODO Remove once no longer referenced by Delta
output "redis_private_subnet_ids" {
  value = module.networking.delta_website_db_private_subnets[*].id
}

output "delta_website_db_private_subnet_ids" {
  value = module.networking.delta_website_db_private_subnets[*].id
}

output "auth_service_private_subnet_ids" {
  value = module.networking.auth_service_private_subnets[*].id
}

output "vpc_id" {
  value = module.networking.vpc.id
}

output "private_dns" {
  value = module.networking.private_dns
}

output "bastion_host_key_fingerprint" {
  value = module.bastion.bastion_host_key_fingerprint_sha256
}

output "bastion_dns_name" {
  value = module.bastion.bastion_dns_name
}

output "bastion_ssh_keys_bucket" {
  value = module.bastion.ssh_keys_bucket
}

output "bastion_sg_id" {
  value = module.bastion.bastion_security_group_id
}

output "codeartifact_domain" {
  value = module.codeartifact.domain
}

output "codeartifact_domain_arn" {
  value = module.codeartifact.domain_arn
}

output "required_dns_records" {
  value = local.external_required_validation_dns_records
}

output "ad_dns_servers" {
  value = module.active_directory.dns_servers
}

output "gh_runner_private_key" {
  value     = module.gh_runner.private_key
  sensitive = true
}

output "jaspersoft_ssh_private_key" {
  value     = tls_private_key.jaspersoft_ssh_key.private_key_openssh
  sensitive = true
}

output "ml_hostname" {
  value = module.marklogic.ml_hostname
}

output "ml_ssh_private_key" {
  value     = module.marklogic.ml_ssh_private_key
  sensitive = true
}

output "ad_management_server_password" {
  value     = module.active_directory.ad_management_server_password
  sensitive = true
}


output "public_albs" {
  value = {
    delta = module.public_albs.delta
    api   = module.public_albs.delta_api
    auth  = module.public_albs.auth
    cpm   = module.public_albs.cpm
  }
  # Includes CloudFront keys
  sensitive = true
}

output "delta_cloudfront_distribution_id" {
  value = module.cloudfront_distributions.delta_cloudfront_distribution_id
}

output "ml_http_target_group_arn" {
  value = module.marklogic.ml_http_target_group_arn
}

output "session_manager_policy_arn" {
  value = module.session_manager_config.policy_arn
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

output "deploy_user_delta_kms_key_arn" {
  value = module.delta_ses_user.deploy_secret_arn
}

output "auth_internal_alb" {
  value = module.auth_internal_alb.alb
}

output "infra_support_iam_role_name" {
  value = module.iam_roles.infra_support_role_name
}
