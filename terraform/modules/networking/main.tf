data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  firewalled_subnets = flatten([aws_subnet.bastion_private_subnets, [aws_subnet.jaspersoft]])
}
