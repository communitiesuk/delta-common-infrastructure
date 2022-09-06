variable "default_tags" {
  type        = map(string)
  description = "Tags to use for each resource"
}

variable "number_of_private_subnets" {
  type    = number
  default = 3
}

variable "number_of_ad_subnets" {
  type    = number
  default = 2
}