variable "number_of_private_subnets" {
  type    = number
  default = 3
}

variable "number_of_public_subnets" {
  description = "Number of public subnets. Must be at least 2 and no more than the number of availability zones in the current region."
  type        = number
  default     = 3
}

variable "number_of_ad_subnets" {
  type    = number
  default = 2
}