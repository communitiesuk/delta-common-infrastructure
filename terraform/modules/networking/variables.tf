variable "default_tags" {
  type        = map(string)
  description = "Tags to use for each resource"
}

variable "number_of_private_subnets" {
  type    = number
  default = 3
}