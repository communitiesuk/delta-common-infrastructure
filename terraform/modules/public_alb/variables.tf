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

variable "s3_log_expiration_days" {
  type = number
}

variable "apply_aws_shield" {
  type    = bool
  default = false
}
