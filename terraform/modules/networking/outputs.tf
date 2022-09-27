output "vpc" {
  value       = aws_vpc.vpc
  description = "Main AWS VPC"
}

output "nat_gateway_ip" {
  value = aws_eip.nat_gateway.public_ip
}

output "public_subnets" {
  value       = aws_subnet.public_subnet
  description = "var.number_of_public_subnets public /24 subnets"
}

output "private_subnets" {
  value       = aws_subnet.private_subnet
  description = "var.number_of_private_subnets private /24 subnets"
}

output "ad_private_subnets" {
  value = aws_subnet.ad_subnet
}

output "ldaps_ca_subnet" {
  value = aws_subnet.ldaps_ca_server
}
