resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    "Name" = "delta-vpc-${var.environment}"
  }
}

resource "aws_default_network_acl" "main" {
  default_network_acl_id = aws_vpc.vpc.default_network_acl_id

  # Allow all intra-VPC traffic
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = aws_vpc.vpc.cidr_block
    from_port  = 0
    to_port    = 0
  }

  dynamic "ingress" {
    for_each = var.open_ingress_cidrs
    content {
      protocol   = "-1"
      rule_no    = ingress.key + 110
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 0
      to_port    = 0
    }
  }

  # Allow HTTPS
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow HTTP
  # TODO: This rule should be removed once all ALBs accept traffic over HTTPS only
  ingress {
    protocol   = "tcp"
    rule_no    = 210
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Allow SSH from allowlisted CIDRs
  dynamic "ingress" {
    for_each = var.ssh_cidr_allowlist
    content {
      protocol   = "tcp"
      rule_no    = ingress.key + 300
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 22
      to_port    = 22
    }
  }

  # Allow Ephemeral ports
  ingress {
    protocol   = "tcp"
    rule_no    = 1000
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    protocol   = "udp"
    rule_no    = 1001
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    protocol   = "icmp"
    rule_no    = 1002
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
    icmp_code  = -1
    icmp_type  = -1
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    "Name" = "vpc-default-acl-${var.environment}"
  }

  lifecycle {
    ignore_changes = [
      subnet_ids
    ]
  }
}
