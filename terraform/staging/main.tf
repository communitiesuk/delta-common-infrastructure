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

locals {
  environment             = "staging"
  organisation_account_id = "448312965134"
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

locals {
  dns_cert_validation_records = setunion(
    module.communities_only_ssl_certs.required_validation_records,
    module.dluhc_dev_only_ssl_certs.required_validation_records,
    module.ssl_certs.required_validation_records,
  )
}

# This dynamically creates resources, so the modules it depends on must be created first
# terraform apply -target module.dluhc_dev_only_ssl_certs -target module.communities_only_ssl_certs -target module.ssl_certs
module "dluhc_dev_validation_records" {
  source         = "../modules/dns_records"
  hosted_zone_id = var.secondary_domain_zone_id
  records        = [for record in local.dns_cert_validation_records : record if endswith(record.record_name, "${var.secondary_domain}.")]
}

module "networking" {
  source              = "../modules/networking"
  vpc_cidr_block      = "10.20.0.0/16"
  environment         = local.environment
  ssh_cidr_allowlist  = var.allowed_ssh_cidrs
  open_ingress_cidrs  = [local.datamart_peering_vpc_cidr]
  ecr_repo_account_id = var.ecr_repo_account_id
}

resource "tls_private_key" "bastion_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "bastion_ssh_key" {
  key_name   = "stg-bastion-ssh-key"
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
  name_prefix             = "stg"
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

  vpc          = module.networking.vpc
  subnet_ids   = module.networking.public_subnets[*].id
  certificates = module.ssl_certs.alb_certs
  environment  = local.environment
}

# Effectively a circular dependency between Cloudfront and the DNS records that DLUHC manage to validate the certificates
# See comment in test/main.tf
module "cloudfront_distributions" {
  source = "../modules/cloudfront_distributions"

  environment  = local.environment
  base_domains = [var.primary_domain, var.secondary_domain]

  # We don't want to restrict staging until we are able to confirm who needs access
  enable_ip_allowlists = false
  all_distribution_ip_allowlist = concat(
    var.allowed_ssh_cidrs,
    ["${module.networking.nat_gateway_ip}/32"]
  )
  delta = {
    alb = module.public_albs.delta
    domain = {
      aliases             = ["delta.${var.secondary_domain}", "delta.${var.primary_domain}"]
      acm_certificate_arn = module.ssl_certs.cloudfront_certs["delta"].arn
    }
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
    local.dns_cert_validation_records,
    module.cloudfront_distributions.required_dns_records,
    module.ses_identity.required_validation_records
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
  source  = "../modules/active_directory"
  edition = "Standard"

  vpc                          = module.networking.vpc
  domain_controller_subnets    = module.networking.ad_private_subnets
  management_server_subnet     = module.networking.ad_management_server_subnet
  number_of_domain_controllers = 2
  ldaps_ca_subnet              = module.networking.ldaps_ca_subnet
  environment                  = local.environment
  rdp_ingress_sg_id            = module.bastion.bastion_security_group_id
  private_dns                  = module.networking.private_dns
  management_instance_type     = "t3.xlarge"
}

module "marklogic_patch_maintenance_window" {
  source = "../modules/maintenance_window"

  environment = local.environment
  prefix      = "ml-instance-patching"
  schedule    = "cron(00 06 ? * TUE *)"
}

module "marklogic" {
  source = "../modules/marklogic"

  default_tags             = var.default_tags
  environment              = local.environment
  vpc                      = module.networking.vpc
  private_subnets          = module.networking.ml_private_subnets
  instance_type            = "r5.xlarge"
  private_dns              = module.networking.private_dns
  data_volume_size_gb      = 200
  patch_maintenance_window = module.marklogic_patch_maintenance_window

  ebs_backup_error_notification_emails = ["Group-DLUHCDeltaNotifications+staging@softwire.com"]
  extra_instance_policy_arn            = module.session_manager_config.policy_arn
}

module "gh_runner" {
  source = "../modules/github_runner"

  subnet_id                 = module.networking.github_runner_private_subnet.id
  environment               = local.environment
  vpc                       = module.networking.vpc
  github_token              = var.github_actions_runner_token
  ssh_ingress_sg_id         = module.bastion.bastion_security_group_id
  private_dns               = module.networking.private_dns
  extra_instance_policy_arn = module.session_manager_config.policy_arn
}

resource "tls_private_key" "jaspersoft_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "jaspersoft_ssh_key" {
  key_name   = "stg-jaspersoft-ssh-key"
  public_key = tls_private_key.jaspersoft_ssh_key.public_key_openssh
}

module "jaspersoft_patch_maintenance_window" {
  source = "../modules/maintenance_window"

  environment = local.environment
  prefix      = "jasper-instance-patching"
  schedule    = "cron(00 06 ? * TUE *)"
}

module "jaspersoft" {
  source                        = "../modules/jaspersoft"
  private_instance_subnet       = module.networking.jaspersoft_private_subnet
  vpc                           = module.networking.vpc
  prefix                        = "dluhc-stg-"
  ssh_key_name                  = aws_key_pair.jaspersoft_ssh_key.key_name
  public_alb                    = module.public_albs.jaspersoft
  allow_ssh_from_sg_id          = module.bastion.bastion_security_group_id
  jaspersoft_binaries_s3_bucket = var.jasper_s3_bucket
  private_dns                   = module.networking.private_dns
  environment                   = local.environment
  extra_instance_policy_arn     = module.session_manager_config.policy_arn
  patch_maintenance_window      = module.jaspersoft_patch_maintenance_window
}

module "ses_identity" {
  source = "../modules/ses_identity"

  domain                              = "datacollection.test.levellingup.gov.uk"
  bounce_complaint_notification_email = "Group-DLUHCDeltaNotifications+staging@softwire.com"
}

module "delta_ses_user" {
  source               = "../modules/ses_user"
  username             = "ses-user-delta-app-${local.environment}"
  ses_identity_arn     = module.ses_identity.arn
  from_address_pattern = "delta-staging@datacollection.test.levellingup.gov.uk"
  environment          = local.environment
  kms_key_arn          = module.marklogic.deploy_user_kms_key_arn
  vpc_id               = module.networking.vpc.id
}

module "cpm_ses_user" {
  source               = "../modules/ses_user"
  username             = "ses-user-cpm-app-${local.environment}"
  ses_identity_arn     = module.ses_identity.arn
  from_address_pattern = "cpm-staging@datacollection.test.levellingup.gov.uk"
  environment          = local.environment
  kms_key_arn          = module.marklogic.deploy_user_kms_key_arn
  vpc_id               = module.networking.vpc.id
}

module "ses_monitoring" {
  source = "../modules/ses_monitoring"
}

module "iam_roles" {
  source = "../modules/iam_roles"

  organisation_account_id = local.organisation_account_id
  environment             = local.environment
  session_manager_key_arn = module.session_manager_config.session_manager_key_arn
}

module "session_manager_config" {
  source      = "../modules/session_manager_config"
  environment = local.environment
}

module "account_security" {
  source                  = "../modules/account_security"
  organisation_account_id = local.organisation_account_id
}
