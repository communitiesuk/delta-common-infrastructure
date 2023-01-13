variable "instance_type" {
  default = "t3.micro"
}

variable "environment" {
  description = "test, staging or prod"
}

variable "subnet_id" {
  type = string
}

variable "github_token" {
  description = "short-lived token to register the runner with the repo"
  type        = string
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

variable "extra_instance_policy_arn" {
  type = string
}
