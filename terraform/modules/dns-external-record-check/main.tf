terraform {
  required_providers {
    dns = {
      source = "hashicorp/dns"
    }
  }
}

data "dns_cname_record_set" "acm" {
  for_each = { for r in var.acm_validation_cnames : r.domain_name => r }
  host     = each.value.resource_record_name

  lifecycle {
    postcondition {
      condition     = self.cname == each.value.resource_record_value
      error_message = "Incorrect ACM validation record, expected ${self.host} CNAME ${each.value.resource_record_value}, got ${self.cname}"
    }
    precondition {
      condition     = each.value.resource_record_type == "CNAME"
      error_message = "ACM validation record is not a CNAME"
    }
  }
}

data "dns_ns_record_set" "delegation" {
  host = var.delegation_details.domain

  lifecycle {
    postcondition {
      condition     = length(self.nameservers) == length(var.delegation_details.nameservers) && length(setsubtract(toset(self.nameservers), toset(var.delegation_details.nameservers))) == 0
      error_message = "Incorrect or missing NS records for domain delegation, expected [${join(", ", self.nameservers)}] to equal [${join(", ", var.delegation_details.nameservers)}]"
    }
  }
}
