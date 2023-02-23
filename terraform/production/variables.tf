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
  default = "dluhc-preprod.uk"
}

variable "allowed_ssh_cidrs" {
  type = list(string)
  default = [
    "31.221.86.178/32", "167.98.33.82/32", "82.163.115.98/32", "87.224.105.250/32", "87.224.116.242/32", # Softwire
    "3.11.115.33/32",                                                                                    # TSO (Vinod)
  ]
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

variable "hosted_zone_id" {
  type    = string
  default = "Z05291902D4B4GXLXJDZQ"
}

variable "dap_external_role_arn" {
  type    = string
  default = "arn:aws:iam::062321884391:role/DSQL1"
}
