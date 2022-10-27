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

module "networking" {
  source             = "../modules/networking"
  vpc_cidr_block     = "10.30.0.0/16"
  environment        = "prod"
  ssh_cidr_allowlist = var.allowed_ssh_cidrs
}

module "bastion" {
  source = "git::https://github.com/Softwire/terraform-bastion-host-aws?ref=33ed83e0ae4d2c4c955ad05fd3377786fdc31b68"

  region                  = "eu-west-1"
  name_prefix             = "prd"
  vpc_id                  = module.networking.vpc.id
  public_subnet_ids       = [for subnet in module.networking.public_subnets : subnet.id]
  instance_subnet_ids     = [for subnet in module.networking.bastion_private_subnets : subnet.id]
  admin_ssh_key_pair_name = "bastion-ssh-prod" # private key stored in AWS Secrets Manager as "bastion-ssh-private-key"
  external_allowed_cidrs  = var.allowed_ssh_cidrs
  instance_count          = 1

  tags_asg = var.default_tags
}

# We create the codeartifact domain only in the production environment, and it is be shared across all environments
module "codeartifact" {
  source                   = "../modules/codeartifact"
  codeartifact_domain_name = "delta"
}
