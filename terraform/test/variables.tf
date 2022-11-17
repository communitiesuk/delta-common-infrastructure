variable "default_tags" {
  type = map(string)
  default = {
    project           = "Data Collection Service"
    business-unit     = "Digital Delivery"
    technical-contact = "Team-DLUHC@softwire.com"
    environment       = "test"
    repository        = "https://github.com/communitiesuk/delta-common-infrastructure"
  }
}

variable "primary_domain" {
  type    = string
  default = "test.communities.gov.uk"
}

variable "secondary_domain" {
  type    = string
  default = "dluhc-dev.uk"
}

variable "secondary_domain_zone_id" {
  type    = string
  default = "Z01933661AZKA62MUJ054"
}

variable "delegated_domain" {
  type    = string
  default = "internal.delta-test.ramchandani.dev"
}

variable "allowed_ssh_cidrs" {
  type    = list(string)
  default = ["31.221.86.178/32", "167.98.33.82/32", "82.163.115.98/32", "87.224.105.250/32", "87.224.18.46/32"]
}

variable "github_actions_runner_token" {
  type        = string
  default     = "invalid-token"
  description = "Token to register the VPC internal GitHub runner with GitHub. This token is short lived and only needs to be provided for the apply where the GitHub runner is created."
}

# Bucket containing JasperReports zip, see modules/jaspersoft/README for details
variable "jasper_s3_bucket" {
  type    = string
  default = "dluhc-jaspersoft-bin"
}

variable "ecr_repo_account_id" {
  type        = string
  description = "AWS account id containing the ECR repo that ECS services will pull from"
  default     = "468442790030"
}
