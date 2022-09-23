variable "environment" {
  description = "test, staging or production"
  type        = string
}

variable "vpc" {
  description = "The main VPC"
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

variable "management_instance_type" {
  description = "Instance type for the Management EC2 instance"
  type        = string
  default     = "t3.micro"
}
