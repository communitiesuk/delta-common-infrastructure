output "delta_internal_subnet_ids" {
  value = module.networking.delta_internal_subnets[*].id
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
  value = local.all_validation_dns_records
}

output "patch_maintenance_window" {
  value = module.patch_maintenance_window
}
