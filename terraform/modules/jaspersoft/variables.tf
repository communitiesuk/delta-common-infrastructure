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

variable "alb_log_expiration_days" {
  type    = number
  default = 180
}

variable "public_alb_subnets" {
  type = list(object({ id = string }))
}

variable "private_instance_subnet" {
  type = object({ id = string, cidr_block = string })
}

variable "allow_ssh_from_sg_id" {
  description = "This sg will be allowed to connect to the Jasper Server instance on port 22"
  type        = string
}

variable "jaspersoft_binaries_s3_bucket" {
  description = "Existing S3 bucket containing Jaspersoft binaries. See README.md"
  type        = string
}

variable "instance_type" {
  default = "t3.medium"
  type    = string
}

variable "java_max_heap" {
  description = "Maximum memory allocated to tomcat on the Jaspersoft instance (the -Xmx JAVA_OPTS flag)"
  default     = "4096m"
  type        = string
}