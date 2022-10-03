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

  default_tags {
    tags = var.default_tags
  }
}

resource "aws_route53_delegation_set" "main" {
  reference_name = "delta-test"
}

# This module must be created, along with relevant DNS records, before other modules
module "dns" {
  source = "../modules/dns"

  primary_domain    = var.primary_domain
  delegated_domain  = var.delegated_domain
  delegation_set_id = aws_route53_delegation_set.main.id
  prefix            = "delta-test-"
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
  private_instance_subnet       = module.networking.japsersoft_private_subnet
  vpc_id                        = module.networking.vpc.id
  prefix                        = "dluhc-test-"
  ssh_key_name                  = aws_key_pair.jaspersoft_ssh_key.key_name
  public_alb_subnets            = module.networking.public_subnets
  allow_ssh_from_sg_id          = module.bastion.bastion_security_group_id
  jaspersoft_binaries_s3_bucket = "dluhc-jaspersoft-bin"
}

module "networking" {
  source               = "../modules/networking"
  number_of_ad_subnets = 2
  vpc_cidr_block       = "10.0.0.0/16"
}

module "active_directory" {
  source = "../modules/active_directory"

  edition                      = "Standard"
  vpc                          = module.networking.vpc
  domain_controller_subnets    = module.networking.ad_private_subnets
  management_server_subnet     = module.networking.private_subnets[0]
  number_of_domain_controllers = 2
  ldaps_ca_subnet              = module.networking.ldaps_ca_subnet
  environment                  = "test"
  rdp_ingress_sg_id            = module.bastion.bastion_security_group_id
}

resource "tls_private_key" "bastion_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "bastion_ssh_key" {
  key_name   = "tst-bastion-ssh-key"
  public_key = tls_private_key.bastion_ssh_key.public_key_openssh
}

locals {
  bastion_domain = "bastion.${var.delegated_domain}"
}

module "bastion" {
  source = "git::https://github.com/Softwire/terraform-bastion-host-aws?ref=defd0b730d75c1b64cc1e1c76cdd5dc442d6fde6"

  region                  = "eu-west-1"
  name_prefix             = "tst"
  vpc_id                  = module.networking.vpc.id
  public_subnet_ids       = [for subnet in module.networking.public_subnets : subnet.id]
  instance_subnet_ids     = [for subnet in module.networking.private_subnets : subnet.id]
  admin_ssh_key_pair_name = aws_key_pair.bastion_ssh_key.key_name
  external_allowed_cidrs  = ["31.221.86.178/32", "167.98.33.82/32", "82.163.115.98/32", "87.224.105.250/32", "87.224.18.46/32"]
  instance_count          = 1
  dns_config = {
    zone_id = module.dns.delegated_zone_id
    domain  = local.bastion_domain
  }

  tags_asg = var.default_tags
}
