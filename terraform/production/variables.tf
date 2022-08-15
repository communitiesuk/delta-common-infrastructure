variable "default_tags" {
  type = map(string)
  default = {
    system = "Datamart"
    tech-contact-email     = "Team-DLUHC@softwire.com"
    environment            = "production"
  }
}

variable "marklogic_username" {
  type      = string
  sensitive = true
}

variable "marklogic_password" {
  type      = string
  sensitive = true
}
