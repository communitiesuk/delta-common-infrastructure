output "ad_management_server_private_ip" {
  value = module.active_directory.ad_management_server_private_ip
}

output "ad_management_server_password" {
  value     = module.active_directory.ad_management_server_password
  sensitive = true
}

output "ad_ca_server_private_key" {
  value     = module.active_directory.ca_server_private_key
  sensitive = true
}

output "directory_admin_password" {
  value     = module.active_directory.directory_admin_password
  sensitive = true
}

output "ad_dns_servers" {
  value       = module.active_directory.dns_servers
  description = "IP addresses of the managed AD's DNS servers"
}

output "ml_hostname" {
  value = module.marklogic.ml_hostname
}

output "ml_ssh_private_key" {
  value     = module.marklogic.ml_ssh_private_key
  sensitive = true
}

output "jaspersoft_private_ip" {
  value = module.jaspersoft.instance_private_ip
}

output "jaspersoft_ssh_private_key" {
  value     = tls_private_key.jaspersoft_ssh_key.private_key_openssh
  sensitive = true
}

output "mailhog_ssh_private_key" {
  value     = module.mailhog.ssh_private_key
  sensitive = true
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

output "bastion_ssh_private_key" {
  value     = tls_private_key.bastion_ssh_key.private_key_openssh
  sensitive = true
}

output "bastion_sg_id" {
  value = module.bastion.bastion_security_group_id
}

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

output "keycloak_private_subnet_ids" {
  value = module.networking.keycloak_private_subnets[*].id
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

output "gh_runner_private_key" {
  value     = module.gh_runner.private_key
  sensitive = true
}

output "private_dns" {
  value = module.networking.private_dns
}

output "required_dns_records" {
  value = [for record in local.all_dns_records : record if !endswith(record.record_name, "${var.secondary_domain}.")]
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

output "marklogic_deploy_user" {
  value = module.marklogic.deploy_user
}

output "ml_http_target_group_arn" {
  value = module.marklogic.ml_http_target_group_arn
}

output "session_manager_policy_arn" {
  value = data.aws_iam_policy.enable_session_manager.arn
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

output "auth_internal_alb" {
  value = module.auth_internal_alb.alb
}

output "infra_support_iam_role_name" {
  value = module.iam_roles.infra_support_role_name
}
