resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "igw-${var.environment}"
  }
}
