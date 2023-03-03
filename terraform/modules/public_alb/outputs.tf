output "arn" {
  value = aws_lb.main.arn
}

output "dns_name" {
  value = aws_lb.main.dns_name
}

output "security_group_id" {
  value = aws_security_group.alb.id
}

output "arn_suffix" {
  value = aws_lb.main.arn_suffix
}
