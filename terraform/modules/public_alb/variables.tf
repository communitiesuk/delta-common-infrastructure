variable "vpc" {
  type = object({
    id         = string
    cidr_block = string
  })
}

variable "prefix" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "log_expiration_days" {
  type = number
}
