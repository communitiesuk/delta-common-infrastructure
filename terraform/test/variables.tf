variable "default_tags" {
  type = map(string)
  default = {
    project           = "Data Collection Service"
    business-unit     = "Digital Delivery"
    technical-contact = "Team-DLUHC@softwire.com"
    environment       = "test"
    repository        = "https://github.com/communitiesuk/delta-common-infrastructure"
  }
}

variable "primary_domain" {
  type    = string
  default = "delta-test.ramchandani.dev"
}

variable "delegated_domain" {
  type    = string
  default = "internal.delta-test.ramchandani.dev"
}

variable "allowed_ssh_cidrs" {
  type    = list(string)
  default = ["31.221.86.178/32", "167.98.33.82/32", "82.163.115.98/32", "87.224.105.250/32", "87.224.18.46/32"]
}

# Bucket containing JasperReports zip, see modules/jaspersoft/README for details
variable "jasper_s3_bucket" {
  type    = string
  default = "dluhc-jaspersoft-bin"
}
