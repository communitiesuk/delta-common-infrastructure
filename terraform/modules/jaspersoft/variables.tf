variable "environment" {
  type = string
}

variable "prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "ssh_key_name" {
  type = string
}
