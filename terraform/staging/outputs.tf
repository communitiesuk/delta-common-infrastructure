output "ad_management_server_private_ip" {
  value = module.active_directory.ad_management_server_private_ip
}

output "ad_management_server_password" {
  value     = module.active_directory.ad_management_server_password
  sensitive = true
}

output "ca_server_private_key" {
  value     = module.active_directory.ca_server_private_key
  sensitive = true
}

output "directory_admin_password" {
  value     = module.active_directory.directory_admin_password
  sensitive = true
}

output "ad_dns_servers" {
  value = module.active_directory.dns_servers
}

output "ml_hostname" {
  value = module.marklogic.ml_hostname
}

output "ml_ssh_private_key" {
  value     = module.marklogic.ml_ssh_private_key
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

output "delta_internal_subnet_ids" {
  value = module.networking.delta_internal_subnets[*].id
}

output "vpc_id" {
  value = module.networking.vpc.id
}

output "gh_runner_ip" {
  value = module.gh_runner.instance_ip
}

output "gh_runner_private_key" {
  value     = module.gh_runner.private_key
  sensitive = true
}

output "jaspersoft_alb_domain" {
  value = module.jaspersoft.jaspersoft_alb_domain
}

output "jaspersoft_private_ip" {
  value = module.jaspersoft.instance_private_ip
}

output "jaspersoft_ssh_private_key" {
  value     = tls_private_key.jaspersoft_ssh_key.private_key_openssh
  sensitive = true
}
