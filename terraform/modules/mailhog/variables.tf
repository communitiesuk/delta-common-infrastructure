variable "environment" {
  type = string
}

variable "private_subnet" {
  type = object({
    id         = string
    cidr_block = string
  })
}

variable "vpc" {
  type = object({
    id         = string
    cidr_block = string
  })
}

variable "ssh_ingress_sg_id" {
  type        = string
  description = "Security group id to allow SSH ingress from"
}

variable "private_dns" {
  type = object({
    zone_id     = string
    base_domain = string
  })
}

variable "public_dns" {
  type = object({
    zone_id     = string
    base_domain = string
  })
}

variable "public_subnet_ids" {
  type = list(string)
}
