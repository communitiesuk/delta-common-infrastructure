terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.36"
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

  required_version = "~> 1.3.0"
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = var.default_tags
  }
}

resource "aws_route53_delegation_set" "main" {
  reference_name = "delta-test"
}

module "dns" {
  source = "../modules/dns"

  primary_domain    = var.primary_domain
  delegated_domain  = var.delegated_domain
  delegation_set_id = aws_route53_delegation_set.main.id
  prefix            = "delta-test-"
}

module "networking" {
  source                         = "../modules/networking"
  vpc_cidr_block                 = "10.0.0.0/16"
  environment                    = "test"
  ssh_cidr_allowlist             = var.allowed_ssh_cidrs
  ecr_repo_account_id            = var.ecr_repo_account_id
  number_of_vpc_endpoint_subnets = 1
}

resource "tls_private_key" "bastion_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "bastion_ssh_key" {
  key_name   = "tst-bastion-ssh-key"
  public_key = tls_private_key.bastion_ssh_key.public_key_openssh
}

module "bastion" {
  source = "git::https://github.com/Softwire/terraform-bastion-host-aws?ref=11b10ed6805a4bdd7a5e983f8c90cf40a4c43bad"

  region                  = "eu-west-1"
  name_prefix             = "tst"
  vpc_id                  = module.networking.vpc.id
  public_subnet_ids       = [for subnet in module.networking.public_subnets : subnet.id]
  instance_subnet_ids     = [for subnet in module.networking.bastion_private_subnets : subnet.id]
  admin_ssh_key_pair_name = aws_key_pair.bastion_ssh_key.key_name
  external_allowed_cidrs  = var.allowed_ssh_cidrs
  instance_count          = 1
  dns_config = {
    zone_id = module.dns.delegated_zone_id
    domain  = "bastion.${var.delegated_domain}"
  }
  extra_userdata = "yum install openldap-clients -y"

  tags_asg = var.default_tags
}

module "active_directory" {
  source = "../modules/active_directory"

  edition                      = "Standard"
  vpc                          = module.networking.vpc
  domain_controller_subnets    = module.networking.ad_private_subnets
  management_server_subnet     = module.networking.ad_management_server_subnet
  number_of_domain_controllers = 2
  ldaps_ca_subnet              = module.networking.ldaps_ca_subnet
  environment                  = "test"
  rdp_ingress_sg_id            = module.bastion.bastion_security_group_id
  private_dns                  = module.networking.private_dns
  ad_domain                    = "dluhctest.local"
  ad_netbios_name              = "DLUHCTEST"
  management_instance_type     = "t3.xlarge"
  include_ca                   = false
}

module "active_directory_dns_resolver" {
  source = "../modules/active_directory_dns_resolver"

  vpc               = module.networking.vpc
  ad_dns_server_ips = module.active_directory.dns_servers
}

module "marklogic" {
  source = "../modules/marklogic"

  default_tags    = var.default_tags
  environment     = "test"
  vpc             = module.networking.vpc
  private_subnets = module.networking.ml_private_subnets
  instance_type   = "t3.large"
  private_dns     = module.networking.private_dns
}

module "gh_runner" {
  source = "../modules/github_runner"

  subnet_id         = module.networking.github_runner_private_subnet.id
  environment       = "test"
  vpc               = module.networking.vpc
  github_token      = var.github_actions_runner_token
  ssh_ingress_sg_id = module.bastion.bastion_security_group_id
  private_dns       = module.networking.private_dns
}

resource "tls_private_key" "jaspersoft_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "jaspersoft_ssh_key" {
  key_name   = "tst-jaspersoft-ssh-key"
  public_key = tls_private_key.jaspersoft_ssh_key.public_key_openssh
}

module "jaspersoft" {
  source                        = "../modules/jaspersoft"
  private_instance_subnet       = module.networking.jaspersoft_private_subnet
  vpc_id                        = module.networking.vpc.id
  prefix                        = "dluhc-test-"
  ssh_key_name                  = aws_key_pair.jaspersoft_ssh_key.key_name
  public_alb_subnets            = module.networking.public_subnets
  allow_ssh_from_sg_id          = module.bastion.bastion_security_group_id
  jaspersoft_binaries_s3_bucket = var.jasper_s3_bucket
  enable_backup                 = true
  private_dns                   = module.networking.private_dns
  ad_domain                     = "dluhctest"
  environment                   = "test"
}

locals {
  cloudfront_subdomains = ["nginx-test", "reporting"]
}

module "cloudfront" {
  source             = "../modules/cloudfront"
  nginx_test_subnet  = module.networking.public_subnets[0]
  vpc                = module.networking.vpc
  prefix             = "dluhc-test-"
  public_alb_subnets = module.networking.public_subnets
  cloudfront_domain = {
    aliases             = flatten([for s in local.cloudfront_subdomains : ["${s}.${var.delegated_domain}", "${s}.${var.primary_domain}"]])
    acm_certificate_arn = module.dns.cloudfront_domains_certificate_arn
  }
}

resource "aws_route53_record" "delegated_cloudfront_domains" {
  for_each = toset([for s in local.cloudfront_subdomains : "${s}.${var.delegated_domain}"])
  zone_id  = module.dns.delegated_zone_id
  name     = each.key
  type     = "A"

  alias {
    name                   = module.cloudfront.cloudfront_domain_name
    zone_id                = module.cloudfront.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}
