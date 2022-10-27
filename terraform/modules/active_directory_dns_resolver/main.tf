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

data "aws_region" "current" {}

resource "aws_vpc_dhcp_options" "dns_resolver" {
  # Add the Amazon provided DNS server to the end of the list as a backup in case AD doesn't respond
  domain_name_servers = concat(var.ad_dns_server_ips, ["AmazonProvidedDNS"])
  # Marklogic needs to be able to resolve other hosts in the cluster by their hostnames,
  # which default to e.g. ip-1-2-3-4 which need this search base to resolve correctly.
  domain_name = "${data.aws_region.current.name}.compute.internal"
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = var.vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.dns_resolver.id
}
