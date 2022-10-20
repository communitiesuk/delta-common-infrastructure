data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  firewall_config = {
    bastion = {
      subnets              = aws_subnet.bastion_private_subnets
      cidr                 = local.bastion_subnet_cidr_10
      http_allowed_domains = ["example.com"]
      tls_allowed_domains  = ["http.cat"]
      sid_offset           = 100
    }
    jaspersoft = {
      subnets              = [aws_subnet.jaspersoft]
      cidr                 = local.jaspersoft_cidr_10
      http_allowed_domains = [".ubuntu.com", ".launchpad.net", ".postgresql.org"]
      tls_allowed_domains  = [".ubuntu.com", ".launchpad.net", "archive.apache.org", ".postgresql.org"]
      sid_offset           = 200
    }
  }
  firewalled_subnets = flatten([for name, config in local.firewall_config : config.subnets])
}

resource "aws_security_group" "aws_service_vpc_endpoints" {
  name        = "vpc-endpoints-${var.environment}"
  description = "VPC Endpoint security group"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Connections from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
}
