variable "default_tags" {
  type        = map(string)
  description = "Tags to use for each resource"
}

variable "environment" {
  description = "test, staging or production"
  type        = string
}

variable "vpc" {
  description = "The main VPC"
}

variable "directory_admin_password" {
  description = "Password for admin user"
  type        = string
}

variable "subnets" {
  description = "Private Subnets for domain controllers (minimum 2)"
}

variable "public_subnet" {
  description = "Public subnets for management server"
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

variable "ad_management_public_key" {
  description = "Public key for connecting to Management EC2 instance"
  type        = string
}

variable "management_instance_type" {
  description = "Instance type for the Management EC2 instance"
  type        = string
  default     = "t3.micro"
}
variable "ca_password" {
  description = "Admin password for AD, to be used by CA server, will be stored in secrets manager"
  type        = string
  sensitive   = true
}