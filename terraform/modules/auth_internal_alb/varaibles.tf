variable "environment" {
  type = string
}

variable "vpc" {
  type = object({
    id         = string
    cidr_block = string
  })
}

variable "subnet_ids" {
  type = list(string)
}

variable "auth_domain" {
  type = string
}

variable "certificate_arn" {
  type = string
}
