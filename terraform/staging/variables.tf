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

variable "ip_allowlist" {
  type = list(string)
  # Detectify surface monitoring tool : see https://www.security.gov.uk/services-resources/cyber-and-domains-protection/detectify-surface-monitoring-tool
  default = ["52.17.9.21/32", "52.17.98.131/32"]
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

variable "ecr_repo_account_id" {
  type        = string
  description = "AWS account id containing the ECR repo that ECS services will pull from"
  default     = "468442790030"
}

variable "dap_external_role_arns" {
  type    = list(string)
  default = []
}

variable "s151_external_aws_principal_arns" {
  type        = list(string)
  description = "Funding service accounts that we wish to have access to staging S151 data in DAP export S3 bucket"
  default = [
    "arn:aws:iam::960556738724:root",
    "arn:aws:iam::012986738649:root",
  ]
}

variable "azure_dap_export_allowed_cidrs" {
  type        = list(string)
  description = "Azure partner CIDRs allowed to use the staging DAP export access key"
  default     = ["4.158.35.41/32"]
}
