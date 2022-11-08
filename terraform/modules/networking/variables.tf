variable "number_of_public_subnets" {
  description = "Number of public subnets. Must be at least 2 and no more than the number of availability zones in the current region."
  type        = number
  default     = 3
}

variable "number_of_ad_subnets" {
  type    = number
  default = 2
}

variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "environment" {
  type = string
}

variable "ssh_cidr_allowlist" {
  description = "CIDR"
  type        = list(string)
}

variable "private_dns_domain" {
  default = "vpc.local"
}

variable "open_ingress_cidrs" {
  description = "Extra CIDRs to allow ingress through the default VPC ACL, for example, from a trusted peered VPC"
  type        = list(string)
  default     = []
}

variable "ecr_repo_account_id" {
  type = string
}

variable "number_of_vpc_endpoint_subnets" {
  default = 3
  type    = number
}
