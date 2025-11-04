variable "default_tags" {
  type = map(string)
  default = {
    project           = "Data Collection Service"
    business-unit     = "Digital Delivery"
    technical-contact = "delta-notifications@communities.gov.uk"
    environment       = "staging"
    repository        = "https://github.com/communitiesuk/delta-common-infrastructure"
  }
}

variable "primary_domain" {
  type    = string
  default = "stage.communities.gov.uk"
}

variable "secondary_domain" {
  type    = string
  default = "stage.dluhc-dev.uk"
}

variable "secondary_domain_zone_id" {
  type    = string
  default = "Z01933661AZKA62MUJ054"
}

variable "allowed_ssh_cidrs" {
  type    = list(string)
  default = []
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

variable "dap_external_role_arns" {
  type    = list(string)
  default = ["arn:aws:iam::062321884391:role/DSQSS"]
}

variable "dap_external_canonical_users" {
  type        = list(string)
  description = "Funding service accounts that we wish to have access to staging DAP S3 bucket"
  default     = ["4a20e1ecba266786127536b068cbbf222b344a2e21024029f1a778f98e8667c0", "5544757b63b565e6774e61121ba15cfa98206f1629455df924f60d942a861d56"]
}

variable "s151_external_role_arns" {
  type    = list(string)
  default = []
}

variable "s151_external_canonical_users" {
  type    = list(string)
  default = []
}
