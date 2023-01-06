terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.36"
    }
  }

  # Requires S3 bucket & Dynamo DB to be configured, please see README.md
  backend "s3" {
    bucket         = "data-collection-service-tfstate-production"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:eu-west-1:468442790030:key/5227677e-1230-49f6-b0d8-1e8aa2fc71fe"
    dynamodb_table = "tfstate-locks"
    key            = "common-infra-prod"
    region         = "eu-west-1"
  }

  required_version = "~> 1.3.0"
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = var.default_tags
  }
}

module "communities_only_ssl_certs" {
  source = "../modules/ssl_certificates"

  primary_domain = var.primary_domain
}

module "ses_identity" {
  source = "../modules/ses_identity"

  domain = "datacollection.levellingup.gov.uk"
}

locals {
  all_validation_dns_records = concat(module.communities_only_ssl_certs.required_validation_records, module.ses_identity.required_validation_records)
}

module "networking" {
  source              = "../modules/networking"
  vpc_cidr_block      = "10.30.0.0/16"
  environment         = "prod"
  ssh_cidr_allowlist  = var.allowed_ssh_cidrs
  ecr_repo_account_id = var.ecr_repo_account_id
}

module "bastion_log_group" {
  source = "../modules/encrypted_log_groups"

  kms_key_alias_name = "production-bastion-ssh-logs"
  log_group_names    = ["production/ssh-bastion"]
  retention_days     = 180
}

module "bastion" {
  source = "git::https://github.com/Softwire/terraform-bastion-host-aws?ref=b567dbf2c9641df277f503240ee4367b126d475c"

  region                  = "eu-west-1"
  name_prefix             = "prd"
  vpc_id                  = module.networking.vpc.id
  public_subnet_ids       = [for subnet in module.networking.public_subnets : subnet.id]
  instance_subnet_ids     = [for subnet in module.networking.bastion_private_subnets : subnet.id]
  admin_ssh_key_pair_name = "bastion-ssh-prod" # private key stored in AWS Secrets Manager as "bastion-ssh-private-key"
  external_allowed_cidrs  = var.allowed_ssh_cidrs
  instance_count          = 1
  log_group_name          = module.bastion_log_group.log_group_names[0]
  extra_userdata          = "yum install openldap-clients -y"
  tags_asg                = var.default_tags
  tags_host_key           = { "terraform-plan-read" = true }
}

# We create the codeartifact domain only in the production environment, and it is shared across all environments
module "codeartifact" {
  source                   = "../modules/codeartifact"
  codeartifact_domain_name = "delta"
}

resource "aws_accessanalyzer_analyzer" "eu-west-1" {
  analyzer_name = "eu-west-1-analyzer"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

resource "aws_accessanalyzer_analyzer" "us-east-1" {
  analyzer_name = "us-east-1-analyzer"
  provider      = aws.us-east-1
}
