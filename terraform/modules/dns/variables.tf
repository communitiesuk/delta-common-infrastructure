variable "primary_domain" {
  description = "For production this would be communities.gov.uk"
  type        = string
}

variable "delegated_domain" {
  description = "A domain delegated for us to manage, e.g. internal.communities.gov.uk"
  type        = string
}

variable "delegation_set_id" {
  type = string
}

variable "prefix" {
  type = string
}
