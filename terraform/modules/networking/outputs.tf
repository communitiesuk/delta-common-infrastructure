output "vpc" {
  value       = aws_vpc.vpc
  description = "Main AWS VPC"
}

output "nat_gateway_ip" {
  value = aws_eip.nat_gateway.public_ip
}

output "public_subnets" {
  value       = aws_subnet.public_subnets
  description = "var.number_of_public_subnets public /24 subnets"
}

output "bastion_private_subnets" {
  value       = aws_subnet.bastion_private_subnets
  description = "Three private /24 subnets"
}

output "ad_private_subnets" {
  value       = aws_subnet.ad_dc_private_subnets
  description = "var.number_of_ad_subnets private /24 subnets"
}

output "ldaps_ca_subnet" {
  value = aws_subnet.ldaps_ca_server
}

output "ad_management_server_subnet" {
  value = aws_subnet.ad_management_server
}

output "ml_private_subnets" {
  value       = aws_subnet.ml_private_subnets
  description = "Three private /24 subnets for MarkLogic"
}

output "ml_min_private_subnets" {
  value       = aws_subnet.ml_min_private_subnets
  description = "Three private /24 subnets for MarkLogic restore from backup rehearsal"
}

output "delta_internal_subnets" {
  value       = aws_subnet.delta_internal
  description = "Three private /24 subnets for internal Delta apps"
}

output "delta_api_subnets" {
  value       = aws_subnet.delta_api
  description = "Three private /24 subnets for internal communications by the Delta api"
}

output "delta_website_subnets" {
  value       = aws_subnet.delta_website
  description = "Three private /24 subnets for the Delta website instances"
}

output "jaspersoft_private_subnets" {
  value       = aws_subnet.jaspersoft
  description = "Two private /24 subnets for Jaspersoft instance and database"
}

output "github_runner_private_subnet" {
  value       = aws_subnet.github_runner
  description = "Private /24 subnet for GitHub runner instance"
}

output "cpm_private_subnets" {
  value       = aws_subnet.cpm_private
  description = "Three private /24 subnets for CPM"
}

output "keycloak_private_subnets" {
  value       = aws_subnet.keycloak_private
  description = "Three private /24 subnets for Keycloak"
}

output "mailhog_private_subnet" {
  value       = var.mailhog_subnet ? aws_subnet.mailhog[0] : null
  description = "Private /24 subnet for MailHog, if enabled"
}

output "delta_website_db_private_subnets" {
  value       = aws_subnet.delta_website_db
  description = "Private /24 subnets for Delta website SQL database and Redis"
}

output "auth_service_private_subnets" {
  value       = aws_subnet.auth_service
  description = "Private /24 subnets for auth service"
}

output "private_dns" {
  value = {
    zone_id     = aws_route53_zone.private.zone_id
    base_domain = aws_route53_zone.private.name
  }
}
