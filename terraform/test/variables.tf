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

variable "directory_admin_password" {
  type = string
  sensitive = true
}

variable "ad_management_public_key" {
  type = string
}
