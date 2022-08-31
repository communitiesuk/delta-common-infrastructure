terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.25"
    }
  }

  # Requires S3 bucket & Dynamo DB to be configured, please see README.md
  backend "s3" {
    bucket         = "data-collection-service-tfstate-dev"
    encrypt        = true
    dynamodb_table = "tfstate-locks"
    key            = "common-infra-test"
    region         = "eu-west-1"
  }

  required_version = "~> 1.2.0"
}

provider "aws" {
  region = "eu-west-1"
}

module "networking" {
  source                    = "../modules/networking"
  number_of_private_subnets = 3
  number_of_ad_subnets      = 2
  default_tags              = var.default_tags
}

module "active_directory" {
  source = "../modules/active_directory"

  default_tags                 = var.default_tags
  edition                      = "Standard"
  vpc                          = module.networking.vpc
  subnets                      = module.networking.ad_private_subnets
  public_subnet                = module.networking.ad_public_subnet
  number_of_domain_controllers = 2
  ad_management_public_key     = var.ad_management_public_key
  directory_admin_password     = var.directory_admin_password
  ldaps_ca_subnet              = module.networking.ldaps_ca_subnet
  environment                  = "test"
  ca_password                  = var.directory_admin_password
}