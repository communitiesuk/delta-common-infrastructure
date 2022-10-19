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
  vpc_cidr_block     = "10.20.0.0/16"
  environment        = "staging"
  ssh_cidr_allowlist = var.allowed_ssh_cidrs
  # TODO DT-58 Circular dependency sadness
  # Should we add 10.20.0.2 as a fallback?
  # Will this break VPC interface endpoint DNS fiddling
  dns_servers = module.active_directory.dns_servers
}

module "active_directory" {
  source  = "../modules/active_directory"
  edition = "Standard"

  vpc                          = module.networking.vpc
  domain_controller_subnets    = module.networking.ad_private_subnets
  management_server_subnet     = module.networking.ad_management_server_subnet
  number_of_domain_controllers = 2
  ldaps_ca_subnet              = module.networking.ldaps_ca_subnet
  environment                  = "staging"
  rdp_ingress_sg_id            = module.bastion.bastion_security_group_id
}

# qq
output "dns" {
  value = module.active_directory.dns_servers
}

module "marklogic" {
  source = "../modules/marklogic"

  default_tags    = var.default_tags
  environment     = "staging"
  vpc             = module.networking.vpc
  private_subnets = module.networking.ml_private_subnets
  instance_type   = "r5.xlarge"
}

resource "tls_private_key" "bastion_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "bastion_ssh_key" {
  key_name   = "stg-bastion-ssh-key"
  public_key = tls_private_key.bastion_ssh_key.public_key_openssh
}


module "bastion" {
  source = "git::https://github.com/Softwire/terraform-bastion-host-aws?ref=defd0b730d75c1b64cc1e1c76cdd5dc442d6fde6"

  region                  = "eu-west-1"
  name_prefix             = "stg"
  vpc_id                  = module.networking.vpc.id
  public_subnet_ids       = [for subnet in module.networking.public_subnets : subnet.id]
  instance_subnet_ids     = [for subnet in module.networking.bastion_private_subnets : subnet.id]
  admin_ssh_key_pair_name = aws_key_pair.bastion_ssh_key.key_name
  external_allowed_cidrs  = var.allowed_ssh_cidrs
  instance_count          = 1

  tags_asg = var.default_tags
}

module "gh_runner" {
  source = "../modules/github_runner"

  subnet_id         = module.networking.ml_private_subnets[0].id
  environment       = "staging"
  vpc               = module.networking.vpc
  ssh_ingress_sg_id = module.bastion.bastion_security_group_id
}
