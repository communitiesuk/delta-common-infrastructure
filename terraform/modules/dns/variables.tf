variable "primary_domain" {
  description = "For production this would be communities.gov.uk"
  type        = string
}

variable "delegated_domain" {
  description = "A domain delegated for us to manage, e.g. infra.communities.gov.uk"
  type        = string
}

variable "prefix" {
  type = string
}
