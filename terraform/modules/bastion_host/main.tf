locals {
  # IPv4 and IPv6 record types will be created
  dns_record_types = ["A", "AAAA"]

  instance_count = var.instance_count != -1 ? var.instance_count : length(var.instance_subnet_ids)
}

data "aws_vpc" "bastion" {
  id = var.vpc_id
}

data "aws_subnet" "public_subnets" {
  count = length(var.public_subnet_ids)
  id    = var.public_subnet_ids[count.index]
}
