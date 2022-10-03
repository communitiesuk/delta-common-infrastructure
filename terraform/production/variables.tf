variable "default_tags" {
  type = map(string)
  default = {
    project           = "Data Collection Service"
    business-unit     = "Digital Delivery"
    technical-contact = "Team-DLUHC@softwire.com"
    environment       = "production"
    repository        = "https://github.com/communitiesuk/delta-common-infrastructure"
  }
}

variable "allowed_ssh_cidrs" {
  type    = list(string)
  default = ["31.221.86.178/32", "167.98.33.82/32", "82.163.115.98/32", "87.224.105.250/32", "87.224.18.46/32"]
}
