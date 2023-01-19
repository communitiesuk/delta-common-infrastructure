terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.50"
    }
  }

  # Requires S3 bucket & Dynamo DB to be configured, please see README.md
  backend "s3" {
    bucket         = "data-collection-service-tfstate-dev"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:eu-west-1:486283582667:key/547ae46f-f57e-45f6-bcfd-9403bed9ec75"
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

locals {
  environment = "test"
}

# In practice the ACM validation records will all overlap
# But create three sets anyway to be on the safe side, ACM is free
module "ssl_certs" {
  source = "../modules/ssl_certificates"

  primary_domain    = var.primary_domain
  secondary_domains = [var.secondary_domain]
}

module "communities_only_ssl_certs" {
  source = "../modules/ssl_certificates"

  primary_domain = var.primary_domain
}

module "dluhc_dev_only_ssl_certs" {
  source = "../modules/ssl_certificates"

  primary_domain = var.secondary_domain
}

module "ses_identity" {
  source = "../modules/ses_identity"

  domain                              = "datacollection.${var.secondary_domain}"
  bounce_complaint_notification_email = "Group-DLUHCDeltaNotifications+test@softwire.com"
}

locals {
  dns_cert_and_email_validation_records = setunion(
    module.communities_only_ssl_certs.required_validation_records,
    module.dluhc_dev_only_ssl_certs.required_validation_records,
    module.ssl_certs.required_validation_records,
    module.ses_identity.required_validation_records
  )
}

# This dynamically creates resources, so the modules it depends on must be created first
# terraform apply -target module.dluhc_dev_only_ssl_certs -target module.communities_only_ssl_certs -target module.ssl_certs -target module.ses_identity
module "dluhc_dev_validation_records" {
  source         = "../modules/dns_records"
  hosted_zone_id = var.secondary_domain_zone_id
  records        = [for record in local.dns_cert_and_email_validation_records : record if endswith(record.record_name, "${var.secondary_domain}.")]
}

module "networking" {
  source                         = "../modules/networking"
  vpc_cidr_block                 = "10.0.0.0/16"
  environment                    = local.environment
  ssh_cidr_allowlist             = var.allowed_ssh_cidrs
  ecr_repo_account_id            = var.ecr_repo_account_id
  number_of_vpc_endpoint_subnets = 1
  mailhog_subnet                 = true
}

resource "tls_private_key" "bastion_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "bastion_ssh_key" {
  key_name   = "tst-bastion-ssh-key"
  public_key = tls_private_key.bastion_ssh_key.public_key_openssh
}

module "bastion_log_group" {
  source = "../modules/encrypted_log_groups"

  kms_key_alias_name = "${local.environment}-bastion-ssh-logs"
  log_group_names    = ["${local.environment}/ssh-bastion"]
}

module "bastion" {
  source = "git::https://github.com/Softwire/terraform-bastion-host-aws?ref=f45b89c31b1e02e625d0c6d92a92463ebb8383b9"

  region                  = "eu-west-1"
  name_prefix             = "tst"
  vpc_id                  = module.networking.vpc.id
  public_subnet_ids       = [for subnet in module.networking.public_subnets : subnet.id]
  instance_subnet_ids     = [for subnet in module.networking.bastion_private_subnets : subnet.id]
  admin_ssh_key_pair_name = aws_key_pair.bastion_ssh_key.key_name
  external_allowed_cidrs  = var.allowed_ssh_cidrs
  instance_count          = 1
  log_group_name          = module.bastion_log_group.log_group_names[0]
  extra_userdata          = "yum install openldap-clients -y; sed -i 's/SELINUX=disabled/SELINUX=enforcing/g' /etc/selinux/config ; chmod 754 /usr/bin/as"
  tags_asg                = var.default_tags
  tags_host_key           = { "terraform-plan-read" = true }
  dns_config = {
    zone_id = var.secondary_domain_zone_id
    domain  = "bastion.${var.secondary_domain}"
  }
  s3_access_log_expiration_days = 180
}

module "public_albs" {
  source = "../modules/public_albs"

  vpc                           = module.networking.vpc
  subnet_ids                    = module.networking.public_subnets[*].id
  certificates                  = module.ssl_certs.alb_certs
  environment                   = local.environment
  apply_aws_shield_to_delta_alb = false
}

# Effectively a circular dependency between Cloudfront and the DNS records that DLUHC manage to validate the certificates.
# This is intentional as we want to be able to create a new environment and give DLUHC all
# the required DNS records in one go as approval can take several weeks.
# To create a new environment remove all the "domain" values in this module's inputs (or set them to a domain we control), then create this module,
# then the DNS records, then add the "domain" values back in.
module "cloudfront_distributions" {
  source = "../modules/cloudfront_distributions"

  environment           = local.environment
  base_domains          = [var.primary_domain, var.secondary_domain]
  waf_per_ip_rate_limit = 100000

  # Adding 0.0.0.0/0 to an ipset is not allowed and we don't want to restrict test
  enable_ip_allowlists = false
  all_distribution_ip_allowlist = concat(
    var.allowed_ssh_cidrs,
    ["${module.networking.nat_gateway_ip}/32"]
  )
  apply_aws_shield_to_delta_website = false
  delta = {
    alb = module.public_albs.delta
    domain = {
      aliases             = ["delta.${var.secondary_domain}", "delta.${var.primary_domain}"]
      acm_certificate_arn = module.ssl_certs.cloudfront_certs["delta"].arn
    }
    disable_geo_restriction = true
  }
  api = {
    alb = module.public_albs.delta_api
    domain = {
      aliases             = ["api.delta.${var.secondary_domain}", "api.delta.${var.primary_domain}"]
      acm_certificate_arn = module.ssl_certs.cloudfront_certs["api"].arn
    }
  }
  keycloak = {
    alb = module.public_albs.keycloak
    domain = {
      aliases             = ["auth.delta.${var.secondary_domain}", "auth.delta.${var.primary_domain}"]
      acm_certificate_arn = module.ssl_certs.cloudfront_certs["keycloak"].arn
    }
  }
  cpm = {
    alb = module.public_albs.cpm
    domain = {
      aliases             = ["cpm.${var.secondary_domain}", "cpm.${var.primary_domain}"]
      acm_certificate_arn = module.ssl_certs.cloudfront_certs["cpm"].arn
    }
  }
  jaspersoft = {
    alb = module.public_albs.jaspersoft
    domain = {
      aliases             = ["reporting.${var.secondary_domain}", "reporting.${var.primary_domain}"]
      acm_certificate_arn = module.ssl_certs.cloudfront_certs["jaspersoft"].arn
    }
  }
}

locals {
  all_dns_records = setunion(
    local.dns_cert_and_email_validation_records,
    module.cloudfront_distributions.required_dns_records,
  )
}

# This dynamically creates resources, so the modules it depends on must be created first
# terraform apply -target module.cloudfront_distributions
module "dluhc_dev_cloudfront_records" {
  source         = "../modules/dns_records"
  hosted_zone_id = var.secondary_domain_zone_id
  records        = [for record in module.cloudfront_distributions.required_dns_records : record if endswith(record.record_name, "${var.secondary_domain}.")]
}

module "active_directory" {
  source = "../modules/active_directory"

  edition                      = "Standard"
  vpc                          = module.networking.vpc
  domain_controller_subnets    = module.networking.ad_private_subnets
  management_server_subnet     = module.networking.ad_management_server_subnet
  number_of_domain_controllers = 2
  ldaps_ca_subnet              = module.networking.ldaps_ca_subnet
  environment                  = local.environment
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

module "marklogic_patch_maintenance_window" {
  source = "../modules/maintenance_window"

  environment = local.environment
  prefix      = "ml-instance-patching"
  schedule    = "cron(00 06 ? * MON *)"
}

module "marklogic" {
  source = "../modules/marklogic"

  default_tags             = var.default_tags
  environment              = local.environment
  vpc                      = module.networking.vpc
  private_subnets          = module.networking.ml_private_subnets
  instance_type            = "t3.large"
  private_dns              = module.networking.private_dns
  patch_maintenance_window = module.marklogic_patch_maintenance_window

  ebs_backup_error_notification_emails = ["Group-DLUHCDeltaNotifications+test@softwire.com"]
  extra_instance_policy_arn            = data.aws_iam_policy.enable_session_manager.arn
}

module "gh_runner" {
  source = "../modules/github_runner"

  subnet_id                 = module.networking.github_runner_private_subnet.id
  environment               = local.environment
  vpc                       = module.networking.vpc
  github_token              = var.github_actions_runner_token
  ssh_ingress_sg_id         = module.bastion.bastion_security_group_id
  private_dns               = module.networking.private_dns
  extra_instance_policy_arn = data.aws_iam_policy.enable_session_manager.arn
}

resource "tls_private_key" "jaspersoft_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "jaspersoft_ssh_key" {
  key_name   = "tst-jaspersoft-ssh-key"
  public_key = tls_private_key.jaspersoft_ssh_key.public_key_openssh
}

module "jaspersoft_patch_maintenance_window" {
  source = "../modules/maintenance_window"

  environment = local.environment
  prefix      = "jasper-instance-patching"
  schedule    = "cron(00 06 ? * MON *)"
}

module "jaspersoft" {
  source                        = "../modules/jaspersoft"
  private_instance_subnet       = module.networking.jaspersoft_private_subnet
  vpc                           = module.networking.vpc
  prefix                        = "dluhc-${local.environment}-"
  ssh_key_name                  = aws_key_pair.jaspersoft_ssh_key.key_name
  public_alb                    = module.public_albs.jaspersoft
  allow_ssh_from_sg_id          = module.bastion.bastion_security_group_id
  jaspersoft_binaries_s3_bucket = var.jasper_s3_bucket
  private_dns                   = module.networking.private_dns
  ad_domain                     = "dluhctest"
  environment                   = local.environment
  extra_instance_policy_arn     = data.aws_iam_policy.enable_session_manager.arn
  patch_maintenance_window      = module.jaspersoft_patch_maintenance_window
}

module "iam_roles" {
  source = "../modules/iam_roles"

  organisation_account_id = "448312965134"
  environment             = local.environment
  session_manager_key_arn = data.aws_kms_key.session_manager.arn
}

data "aws_kms_key" "session_manager" {
  # Created by the staging environment
  key_id = "alias/session-manager-key"
}

data "aws_iam_policy" "enable_session_manager" {
  # Created by the staging environment
  name = "session-manager-policy"
}

module "ses_user" {
  source               = "../modules/ses_user"
  username             = "ses-user-${local.environment}"
  ses_identity_arn     = module.ses_identity.arn
  from_address_pattern = "*@datacollection.dluhc-dev.uk"
  environment          = local.environment
  kms_key_arn          = null
  vpc_id               = module.networking.vpc.id
}

module "mailhog" {
  source = "../modules/mailhog"

  environment       = local.environment
  vpc               = module.networking.vpc
  ssh_ingress_sg_id = module.bastion.bastion_security_group_id
  private_dns       = module.networking.private_dns
  private_subnet    = module.networking.mailhog_private_subnet
  public_subnet_ids = [for subnet in module.networking.public_subnets : subnet.id]
  public_dns = {
    zone_id     = var.secondary_domain_zone_id
    base_domain = var.secondary_domain
  }
  ses_user = module.ses_user
}
