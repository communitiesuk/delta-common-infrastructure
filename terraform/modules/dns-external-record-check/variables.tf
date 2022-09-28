variable "acm_validation_cnames" {
  type = list(object({
    domain_name           = string
    resource_record_name  = string
    resource_record_type  = string
    resource_record_value = string
  }))
}

variable "delegation_details" {
  type = object({
    domain      = string
    nameservers = list(string)
  })
}
