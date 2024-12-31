variable "region" {
  description = "AWS region name"
}

variable "public_subnet_ids" {
  description = "List of subnet ids where NLB listeners will be deployed. This should have public ingress"
}

variable "instance_subnet_ids" {
  description = "List of subnet ids where instances will be deployed"
}

variable "vpc_id" {
  description = "ID of the VPC where the bastion will be deployed"
}

variable "admin_ssh_key_pair_name" {
  description = "Name of the SSH key pair for the admin user account"
}

variable "name_prefix" {
  description = "Max 3 character prefix to be applied to names of all resources"
  default     = "bst"

  validation {
    condition     = length(var.name_prefix) <= 3
    error_message = "name_prefix must be at most three characters"
  }
}

variable "external_allowed_cidrs" {
  type        = list(string)
  description = "List of CIDRs which can access the bastion"
  default     = ["0.0.0.0/0"]
}

variable "external_ssh_port" {
  type        = number
  description = "Which port to use to SSH into the bastion"
  default     = 22
}

variable "internal_ssh_port" {
  type        = number
  description = "Which port the bastion will use to SSH into other private instances"
  default     = 22
}

variable "instance_count" {
  type        = number
  description = "Number of instances to deploy. Defaults to one per subnet ARN provided"
  default     = -1
}

variable "custom_ami" {
  description = "Provide your own AWS AMI to use - useful if you need specific tools on the bastion"
  default     = ""
}

variable "dns_config" {
  type        = object({ domain = string, zone_id = string })
  description = "DNS record name and the route53 hosted zone where the record will be registered"
  default     = null
}

variable "tags_default" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}

variable "tags_lb" {
  type        = map(string)
  description = "Tags to apply to the bastion load balancer"
  default     = {}
}

variable "tags_asg" {
  type        = map(string)
  description = "Tags to apply to the bastion autoscaling group"
  default     = {}
}

variable "tags_sg" {
  type        = map(string)
  description = "Tags to apply to the bastion security groups"
  default     = {}
}

variable "tags_host_key" {
  type        = map(string)
  description = "Tags to apply to the bastion host key secret and KMS key"
  default     = {}
}

variable "extra_userdata" {
  type        = string
  default     = ""
  description = "Extra commands to append to the instance user data script"
}

variable "log_group_name" {
  type        = string
  default     = null
  description = "Optional log group to send SSH logs to"
}

variable "s3_access_log_expiration_days" {
  type    = number
  default = null
}
