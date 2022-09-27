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

output "bastion_dns_name" {
  value = module.bastion.bastion_dns_name
}

output "bastion_ssh_keys_bucket" {
  value = module.bastion.ssh_keys_bucket

}

output "nginx_test_box_ip" {
  value = module.cloudfront.nginx_test_box_ip
}

output "cf_domain_name" {
  value = module.cloudfront.cf_domain_name
}

output "bastion_ssh_private_key" {
  value     = tls_private_key.bastion_ssh_key.private_key_openssh
  sensitive = true
}
