resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags   = var.default_tags

  lifecycle {
    create_before_destroy = true
  }
}
