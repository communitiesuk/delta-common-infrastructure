#
# Configure DHCP for the VPC to return the Active Directory DNS servers.
# Those servers are then in turn configured to forward requests to the Amazon provided VPC DNS (See active_directory module README)
#
# This means the AD domain (dluhcdata.local) will resolve correctly through AD.
#

variable "ad_dns_server_ips" {
  type = list(string)
}

variable "vpc" {
  type = object({
    id         = string
    cidr_block = string
  })
}

variable "dns_search" {
  type    = string
  default = null
}

locals {
  # Always at VPC CIDR base + 2, e.g. 10.0.0.2
  amazon_provided_vpc_dns = cidrhost(var.vpc.cidr_block, 2)
  # Add the Amazon provided DNS server to the end of the list as a backup in case AD doesn't respond
  dns_servers = concat(var.ad_dns_server_ips, [local.amazon_provided_vpc_dns])
}

resource "aws_vpc_dhcp_options" "dns_resolver" {
  domain_name_servers = local.dns_servers
  domain_name         = var.dns_search
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = var.vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.dns_resolver.id
}
