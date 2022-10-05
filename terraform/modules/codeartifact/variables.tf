variable "prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "codeartifact_domain_name" {
  description = "The name of the code artifact domain. Used as the prefix in DNS hostnames"
  type        = string
}
