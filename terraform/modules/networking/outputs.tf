output "aws_vpc" {
  value       = aws_vpc.vpc
  description = "AWS VPC"
}

output "nat_gateway_ip" {
  value = aws_eip.nat_gateway.public_ip
}
