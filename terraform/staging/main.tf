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
    key            = "common-infra-staging"
    region         = "eu-west-1"
  }

  required_version = "~> 1.2.0"
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = var.default_tags
  }
}

module "networking" {
  source = "../modules/networking"
  default_tags              = var.default_tags
  vpc_cidr_block = "10.20.0.0/16"
}

module "active_directory" {
  source = "../modules/active_directory"

  edition                      = "Standard"
  vpc                          = module.networking.vpc
  subnets                      = module.networking.ad_private_subnets
  public_subnet                = module.networking.ad_public_subnet
  number_of_domain_controllers = 2
  ldaps_ca_subnet              = module.networking.ldaps_ca_subnet
  environment                  = "staging"
}

module "marklogic" {
  source = "../modules/marklogic"

  default_tags = var.default_tags
  environment  = "staging"
  vpc          = module.networking.vpc
  private_subnets = module.networking.ml_private_subnets
  instance_type = "r5.xlarge"
}