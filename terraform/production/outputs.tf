output "delta_internal_subnet_ids" {
  value = module.networking.delta_internal_subnets[*].id
}

output "vpc_id" {
  value = module.networking.vpc.id
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

output "codeartifact_domain" {
  value = module.codeartifact.domain
}

