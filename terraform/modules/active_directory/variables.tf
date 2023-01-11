variable "environment" {
  description = "test, staging or production"
  type        = string

  validation {
    condition     = length(var.environment) <= 10
    error_message = "Max 10 characters"
  }
}

variable "vpc" {
  description = "The main VPC"
}

variable "domain_controller_subnets" {
  description = "Private Subnets for domain controllers (minimum 2)"
  type        = list(object({ id = string }))
}

variable "management_server_subnet" {
  description = "Private subnet for management server"
  type        = object({ id = string })
}

variable "ldaps_ca_subnet" {
  description = "Subnet for the CA server"
}

variable "number_of_domain_controllers" {
  description = "Number of domain controllers (minimum 2)"
  type        = number
  default     = 2
}

variable "edition" {
  description = "Edition (Standard or Enterprise)"
  type        = string
}

variable "management_instance_type" {
  description = "Instance type for the Management EC2 instance"
  type        = string
  default     = "t3.micro"
}

variable "rdp_ingress_sg_id" {
  description = "Id of security group to allow ingress to the AD Management server"
  type        = string
}

variable "private_dns" {
  type = object({
    zone_id     = string
    base_domain = string
  })
}

variable "ad_domain" {
  default = "dluhcdata.local"
}

variable "ad_netbios_name" {
  default = "DLUHCDATA"
}

variable "ent_ca_validity_years" {
  description = "Validity period of the root CA"
  default     = "20"
}

variable "include_ca" {
  type    = bool
  default = true
}
