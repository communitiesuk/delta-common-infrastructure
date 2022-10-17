variable "instance_type" {
  default = "t3.micro"
}

variable "environment" {
  description = "test, staging or prod"
}

variable "subnet_id" {
}

variable "github_token" {
  description = "short-lived token to register the runner with the repo"
}

variable "vpc" {

}