variable "number_of_public_subnets" {
  description = "Number of public subnets. Must be at least 2 and no more than the number of availability zones in the current region."
  type        = number
  default     = 3
}

variable "default_tags" {
  type        = map(string)
  description = "Tags to use for each resource"
}

variable "number_of_ad_subnets" {
  type    = number
  default = 2
}

variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}