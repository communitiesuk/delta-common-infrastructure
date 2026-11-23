output "bastion_security_group_id" {
  description = "Security group of the bastion instances"
  value       = aws_security_group.bastion.id
}

output "bastion_dns_name" {
  value = var.dns_config != null ? aws_route53_record.dns_record[0].name : aws_lb.bastion.dns_name
}

output "ssh_keys_bucket" {
  value = aws_s3_bucket.ssh_keys.bucket
}

output "bastion_host_key_fingerprint_sha256" {
  value = tls_private_key.bastion_host_key.public_key_fingerprint_sha256
}

output "instance_connect_endpoint_id" {
  description = "ID of the EC2 Instance Connect Endpoint, if enabled"
  value       = var.enable_instance_connect_endpoint ? aws_ec2_instance_connect_endpoint.bastion[0].id : null
}
