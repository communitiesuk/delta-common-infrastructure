variable "default_tags" {
  type = map(string)
  default = {
    project           = "Data Collection Service"
    business-unit     = "Digital Delivery"
    technical-contact = "Team-DLUHC@softwire.com"
    environment       = "production"
    repository        = "https://github.com/communitiesuk/delta-common-infrastructure"
  }
}

variable "primary_domain" {
  type    = string
  default = "communities.gov.uk"
}

variable "secondary_domain" {
  type    = string
  default = null
}

variable "secondary_domain_zone_id" {
  type    = string
  default = null
}

variable "allowed_ssh_cidrs" {
  type = list(string)
  default = []
}

variable "ecr_repo_account_id" {
  type        = string
  description = "AWS account id containing the ECR repo that ECS services will pull from"
  default     = "468442790030"
}

variable "github_actions_runner_token" {
  type        = string
  default     = "invalid-token"
  description = "Token to register the VPC internal GitHub runner with GitHub. This token is short lived and only needs to be provided for the apply where the GitHub runner is created."
}

variable "jasper_s3_bucket" {
  type    = string
  default = "dluhc-jaspersoft-bin-prod"
}

variable "dap_external_role_arns" {
  type = list(string)
  # "DSQL1" is DAP's production server.
  # "DSQSS" is DAP's staging/test server. Added here for MSD-54917, informed they exist in the same environment.
  default = ["arn:aws:iam::062321884391:role/DSQL1", "arn:aws:iam::062321884391:role/DSQSS"]
}

variable "dap_external_canonical_users" {
  type    = list(string)
  default = []
}
