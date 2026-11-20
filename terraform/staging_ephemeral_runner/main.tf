terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.33, < 7.0"
    }
  }

  backend "s3" {
    bucket         = "data-collection-service-tfstate-dev"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:eu-west-1:486283582667:key/547ae46f-f57e-45f6-bcfd-9403bed9ec75"
    dynamodb_table = "tfstate-locks"
    key            = "common-infra-staging-ephemeral-runner"
    region         = "eu-west-1"
  }
}

provider "aws" {
  region              = "eu-west-1"
  allowed_account_ids = ["486283582667"]
}

module "fleet" {
  source = "../modules/ephemeral_github_runner"

  environment               = "staging"
  artifact_directory        = "${path.module}/.terraform/runner-artifacts"
  logging_retention_in_days = 60
}

output "webhook_url" { value = module.fleet.webhook_url }
output "runner_log_groups" { value = module.fleet.runner_log_groups }
output "runner_binaries_syncer_name" { value = module.fleet.runner_binaries_syncer_name }
