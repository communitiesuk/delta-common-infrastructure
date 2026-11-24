variable "organisation_account_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "session_manager_key_arn" {
  type = string
}

variable "bastion_instance_connect_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks of the private subnet(s) the bastion's EC2 Instance Connect Endpoint can tunnel into. Leave empty to not grant ec2-instance-connect:OpenTunnel permissions"
  default     = []
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
