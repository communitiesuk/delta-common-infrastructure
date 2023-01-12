resource "aws_default_security_group" "default" {
  # Remove all rules from the default security group to make sure traffic is restricted by default
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "delta-vpc-${var.environment}-default-security-group"
  }
}
