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

output "nginx_test_box_ip" {
  value = module.cloudfront.nginx_test_box_ip
}

output "cloudfront_domain_name" {
  value = module.cloudfront.cloudfront_domain_name
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

output "dns_delegation_details" {
  value = {
    domain      = var.delegated_domain
    nameservers = [for s in aws_route53_delegation_set.main.name_servers : "${s}."]
  }
}

output "dns_acm_validation_records" {
  value = module.dns.cloudfront_domains_certificate_required_validation_records
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

output "delta_api_subnet_ids" {
  value = module.networking.delta_api_subnets[*].id
}

output "public_subnet_ids" {
  value = module.networking.public_subnets[*].id
}

output "cpm_private_subnet_ids" {
  value = module.networking.cpm_private_subnets[*].id
}

output "vpc_id" {
  value = module.networking.vpc.id
}

output "gh_runner_private_key" {
  value     = module.gh_runner.private_key
  sensitive = true
}
