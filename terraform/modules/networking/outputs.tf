output "vpc" {
  value       = aws_vpc.vpc
  description = "Main AWS VPC"
}

output "nat_gateway_ip" {
  value = aws_eip.nat_gateway.public_ip
}

output "ad_private_subnets" {
  value = aws_subnet.ad_subnet
}

output "ad_public_subnet" {
  value = aws_subnet.ad_management_server
}