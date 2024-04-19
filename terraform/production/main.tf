terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.33.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.5"
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

  required_version = "~> 1.7.0"
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = var.default_tags
  }
}

locals {
  apply_aws_shield                     = true
  cloudwatch_log_expiration_days       = 731
  patch_cloudwatch_log_expiration_days = 90
  s3_log_expiration_days               = 731
  all_notifications_email_addresses    = ["Group-DLUHCDeltaNotifications@softwire.com", "Yousuf.Desai@levellingup.gov.uk", "dluhc-delta-dev-cloud-aaaamuljvhexfmcatxqusfyjmm@communities-govuk.slack.com"]
}

module "communities_only_ssl_certs" {
  source = "../modules/ssl_certificates"

  primary_domain             = var.primary_domain
  validate_and_check_renewal = true
}

module "ses_identity" {
  source = "../modules/ses_identity"

  domain                               = "datacollection.levellingup.gov.uk"
  environment                          = local.environment
  email_cloudwatch_log_expiration_days = local.cloudwatch_log_expiration_days
  alarms_sns_topic_arn                 = module.notifications.alarms_sns_topic_arn
}

module "delta_ses_user" {
  source                = "../modules/ses_user"
  username              = "ses-user-delta-app-${local.environment}"
  ses_identity_arn      = module.ses_identity.arn
  from_address_patterns = ["delta@datacollection.levellingup.gov.uk"]
  environment           = local.environment
  kms_key_arn           = module.marklogic.deploy_user_kms_key_arn
  vpc_id                = module.networking.vpc.id
}

module "cpm_ses_user" {
  source                = "../modules/ses_user"
  username              = "ses-user-cpm-app-${local.environment}"
  ses_identity_arn      = module.ses_identity.arn
  from_address_patterns = ["cpm@datacollection.levellingup.gov.uk"]
  environment           = local.environment
  kms_key_arn           = module.marklogic.deploy_user_kms_key_arn
  vpc_id                = module.networking.vpc.id
}

module "ses_monitoring" {
  source               = "../modules/ses_monitoring"
  alarms_sns_topic_arn = module.notifications.alarms_sns_topic_arn
}

locals {
  organisation_account_id = "448312965134"
  environment             = "production"
  external_required_validation_dns_records = setunion(
    module.communities_only_ssl_certs.required_validation_records,
    module.ses_identity.required_validation_records,
  )
}

module "networking" {
  source                                  = "../modules/networking"
  vpc_cidr_block                          = "10.30.0.0/16"
  environment                             = "prod"
  ssh_cidr_allowlist                      = var.allowed_ssh_cidrs
  ecr_repo_account_id                     = var.ecr_repo_account_id
  apply_aws_shield_to_nat_gateway         = local.apply_aws_shield
  auth_server_domains                     = ["auth.delta.${var.primary_domain}"]
  firewall_cloudwatch_log_expiration_days = local.cloudwatch_log_expiration_days
  vpc_flow_cloudwatch_log_expiration_days = local.cloudwatch_log_expiration_days
  alarms_sns_topic_arn                    = module.notifications.alarms_sns_topic_arn
  security_alarms_sns_topic_arn           = module.notifications.security_sns_topic_arn
}

module "bastion_log_group" {
  source = "../modules/encrypted_log_groups"

  kms_key_alias_name = "${local.environment}-bastion-ssh-logs"
  log_group_names    = ["${local.environment}/ssh-bastion"]
  retention_days     = local.cloudwatch_log_expiration_days
}

module "bastion" {
  source = "git::https://github.com/Softwire/terraform-bastion-host-aws?ref=bc9595185a8d805397a9622388f26b1246fafb04"

  region                  = "eu-west-1"
  name_prefix             = "prd"
  vpc_id                  = module.networking.vpc.id
  public_subnet_ids       = [for subnet in module.networking.public_subnets : subnet.id]
  instance_subnet_ids     = [for subnet in module.networking.bastion_private_subnets : subnet.id]
  admin_ssh_key_pair_name = "bastion-ssh-prod" # private key stored in AWS Secrets Manager as "bastion-ssh-private-key"
  external_allowed_cidrs  = var.allowed_ssh_cidrs
  instance_count          = 1
  log_group_name          = module.bastion_log_group.log_group_names[0]
  extra_userdata          = file("${path.module}/../bastion_config.sh")
  tags_asg                = var.default_tags
  tags_host_key           = { "terraform-plan-read" = true }

  dns_config = {
    zone_id = var.hosted_zone_id
    domain  = "bastion.${var.secondary_domain}"
  }
}

# We create the codeartifact domain only in the production environment, and it is shared across all environments
module "codeartifact" {
  source                   = "../modules/codeartifact"
  codeartifact_domain_name = "delta"
}

module "active_directory" {
  source  = "../modules/active_directory"
  edition = "Standard"

  vpc                       = module.networking.vpc
  domain_controller_subnets = module.networking.ad_private_subnets
  management_server_subnet  = module.networking.ad_management_server_subnet
  ldaps_ca_subnet           = module.networking.ldaps_ca_subnet
  environment               = local.environment
  rdp_ingress_sg_id         = module.bastion.bastion_security_group_id
  private_dns               = module.networking.private_dns
  management_instance_type  = "t3a.medium"
  alarms_sns_topic_arn      = module.notifications.alarms_sns_topic_arn
}

module "marklogic_patch_maintenance_window" {
  source = "../modules/maintenance_window"

  environment       = local.environment
  prefix            = "ml-instance-patching"
  schedule          = "cron(00 06 ? * WED *)"
  subscribed_emails = local.all_notifications_email_addresses

  enabled = true
}

module "backup_replication_bucket" {
  source = "../modules/backup_replication_bucket"

  environment                   = local.environment
  s3_access_log_expiration_days = local.s3_log_expiration_days
  compliance_retention_days     = 14 # TODO DT-742 Increase once happy with replication
  object_expiration_days        = 90
}

module "ebs_backup" {
  source = "../modules/ebs_backup"

  environment                          = local.environment
  ebs_backup_error_notification_emails = local.all_notifications_email_addresses
}

moved {
  from = module.marklogic.aws_iam_role.ebs_backup
  to   = module.ebs_backup.aws_iam_role.ebs_backup
}

moved {
  from = module.marklogic.aws_iam_role_policy_attachment.service_backup
  to   = module.ebs_backup.aws_iam_role_policy_attachment.service_backup
}

moved {
  from = module.marklogic.aws_iam_role_policy_attachment.service_restore
  to   = module.ebs_backup.aws_iam_role_policy_attachment.service_restore
}

module "marklogic" {
  source = "../modules/marklogic"

  default_tags             = var.default_tags
  environment              = local.environment
  vpc                      = module.networking.vpc
  private_subnets          = module.networking.ml_private_subnets
  instance_type            = "r5a.8xlarge" # r6a is not allowed (as of 26/02/2023)
  marklogic_ami_version    = "10.0-10.2"
  private_dns              = module.networking.private_dns
  patch_maintenance_window = module.marklogic_patch_maintenance_window
  data_volume = {
    size_gb                = 3000
    iops                   = 16000
    throughput_MiB_per_sec = 1000
  }

  extra_instance_policy_arn               = module.session_manager_config.policy_arn
  app_cloudwatch_log_expiration_days      = local.cloudwatch_log_expiration_days
  patch_cloudwatch_log_expiration_days    = local.patch_cloudwatch_log_expiration_days
  config_s3_log_expiration_days           = local.s3_log_expiration_days
  dap_export_s3_log_expiration_days       = local.s3_log_expiration_days
  backup_s3_log_expiration_days           = local.s3_log_expiration_days
  alarms_sns_topic_arn                    = module.notifications.alarms_sns_topic_arn
  data_disk_usage_alarm_threshold_percent = 55
  dap_external_role_arns                  = var.dap_external_role_arns
  dap_job_notification_emails = concat(
    local.all_notifications_email_addresses,
    ["deltastatsupport@levellingup.gov.uk"]
  )
  backup_replication_bucket          = module.backup_replication_bucket.bucket
  ebs_backup_role_arn                = module.ebs_backup.role_arn
  ebs_backup_completed_sns_topic_arn = module.ebs_backup.sns_topic_arn
}

module "gh_runner" {
  source = "../modules/github_runner"

  subnet_id                      = module.networking.github_runner_private_subnet.id
  environment                    = local.environment
  vpc                            = module.networking.vpc
  github_token                   = var.github_actions_runner_token
  ssh_ingress_sg_id              = module.bastion.bastion_security_group_id
  private_dns                    = module.networking.private_dns
  extra_instance_policy_arn      = module.session_manager_config.policy_arn
  cloudwatch_log_expiration_days = local.cloudwatch_log_expiration_days
}

module "public_albs" {
  source = "../modules/public_albs"

  vpc                           = module.networking.vpc
  subnet_ids                    = module.networking.public_subnets[*].id
  certificates                  = module.communities_only_ssl_certs.alb_certs
  environment                   = local.environment
  apply_aws_shield_to_delta_alb = local.apply_aws_shield
  alb_s3_log_expiration_days    = local.s3_log_expiration_days
  auth_domain                   = "auth.delta.${var.primary_domain}"
}

module "cloudfront_alb_monitoring" {
  source = "../modules/cloudfront_alb_monitoring"
  delta_website = {
    cloudfront_distribution_id = module.cloudfront_distributions.delta_cloudfront_distribution_id
    alb_arn_suffix             = module.public_albs.delta.arn_suffix
    instance_metric_namespace  = "${local.environment}/DeltaServers"
  }
  delta_api = {
    cloudfront_distribution_id = module.cloudfront_distributions.api_cloudfront_distribution_id
    alb_arn_suffix             = module.public_albs.delta_api.arn_suffix
    instance_metric_namespace  = null
  }
  keycloak = {
    cloudfront_distribution_id = module.cloudfront_distributions.auth_cloudfront_distribution_id
    alb_arn_suffix             = module.public_albs.auth.arn_suffix
    instance_metric_namespace  = null
  }
  cpm = {
    cloudfront_distribution_id = module.cloudfront_distributions.cpm_cloudfront_distribution_id
    alb_arn_suffix             = module.public_albs.cpm.arn_suffix
    instance_metric_namespace  = null
  }
  jaspersoft = {
    cloudfront_distribution_id = module.cloudfront_distributions.jaspersoft_cloudfront_distribution_id
    alb_arn_suffix             = module.public_albs.jaspersoft.arn_suffix
    instance_metric_namespace  = "${local.environment}/Jaspersoft"
  }
  alarms_sns_topic_arn          = module.notifications.alarms_sns_topic_arn
  alarms_sns_topic_global_arn   = module.notifications.alarms_sns_topic_global_arn
  security_sns_topic_global_arn = module.notifications.security_sns_topic_global_arn
  enable_aws_shield_alarms      = local.apply_aws_shield
  environment                   = local.environment
}

# Effectively a circular dependency between Cloudfront and the DNS records that DLUHC manage to validate the certificates
# See comment in test/main.tf
module "cloudfront_distributions" {
  source = "../modules/cloudfront_distributions"

  environment                              = local.environment
  base_domains                             = [var.primary_domain]
  apply_aws_shield                         = local.apply_aws_shield
  waf_cloudwatch_log_expiration_days       = local.cloudwatch_log_expiration_days
  cloudfront_access_s3_log_expiration_days = local.s3_log_expiration_days
  swagger_s3_log_expiration_days           = local.s3_log_expiration_days
  alarms_sns_topic_global_arn              = module.notifications.alarms_sns_topic_global_arn
  wait_for_deployment                      = true
  security_sns_topic_global_arn            = module.notifications.security_sns_topic_global_arn

  delta = {
    alb = module.public_albs.delta
    domain = {
      aliases             = ["delta.${var.primary_domain}"]
      acm_certificate_arn = module.communities_only_ssl_certs.cloudfront_certs["delta"].arn
    }
    geo_restriction_countries = ["GB", "IE"]
    origin_read_timeout       = 180 # Required quota increase
  }
  api = {
    alb = module.public_albs.delta_api
    domain = {
      aliases             = ["api.delta.${var.primary_domain}"]
      acm_certificate_arn = module.communities_only_ssl_certs.cloudfront_certs["api"].arn
    }
    ip_allowlist = local.cloudfront_ip_allowlists.delta_api
    # Home Connections claim their servers are in the UK, but they currently get geo-located to US
    geo_restriction_countries = ["GB", "IE", "US"]
  }
  keycloak = {
    alb = module.public_albs.auth
    domain = {
      aliases             = ["auth.delta.${var.primary_domain}"]
      acm_certificate_arn = module.communities_only_ssl_certs.cloudfront_certs["keycloak"].arn
    }
    keycloak_path_ip_allowlist = local.cloudfront_ip_allowlists.delta_api
    # Home Connections claim their servers are in the UK, but they currently get geo-located to US
    geo_restriction_countries = ["GB", "IE", "US"]
  }
  cpm = {
    alb = module.public_albs.cpm
    domain = {
      aliases             = ["cpm.${var.primary_domain}"]
      acm_certificate_arn = module.communities_only_ssl_certs.cloudfront_certs["cpm"].arn
    }
    ip_allowlist              = local.cloudfront_ip_allowlists.cpm
    geo_restriction_countries = ["GB", "IE"]
    origin_read_timeout       = 180 # Required quota increase
  }
  jaspersoft = {
    alb = module.public_albs.jaspersoft
    domain = {
      aliases             = ["reporting.delta.${var.primary_domain}"]
      acm_certificate_arn = module.communities_only_ssl_certs.cloudfront_certs["jaspersoft_delta"].arn
    }
    ip_allowlist              = local.cloudfront_ip_allowlists.jaspersoft
    geo_restriction_countries = ["GB", "IE"]
  }
}

resource "tls_private_key" "jaspersoft_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "jaspersoft_ssh_key" {
  key_name   = "prd-jaspersoft-ssh-key"
  public_key = tls_private_key.jaspersoft_ssh_key.public_key_openssh
}

module "jaspersoft_patch_maintenance_window" {
  source = "../modules/maintenance_window"

  environment       = local.environment
  prefix            = "jasper-instance-patching"
  schedule          = "cron(00 06 ? * WED *)"
  subscribed_emails = local.all_notifications_email_addresses
}

module "jaspersoft" {
  source                               = "../modules/jaspersoft"
  private_instance_subnet              = module.networking.jaspersoft_private_subnets[0]
  database_subnets                     = module.networking.jaspersoft_private_subnets
  vpc                                  = module.networking.vpc
  prefix                               = "dluhc-prd-"
  ssh_key_name                         = aws_key_pair.jaspersoft_ssh_key.key_name
  public_alb                           = module.public_albs.jaspersoft
  allow_ssh_from_sg_id                 = module.bastion.bastion_security_group_id
  jaspersoft_binaries_s3_bucket        = var.jasper_s3_bucket
  private_dns                          = module.networking.private_dns
  environment                          = local.environment
  patch_maintenance_window             = module.jaspersoft_patch_maintenance_window
  instance_type                        = "m6a.large"
  java_max_heap                        = "12G"
  extra_instance_policy_arn            = module.session_manager_config.policy_arn
  patch_cloudwatch_log_expiration_days = local.patch_cloudwatch_log_expiration_days
  config_s3_log_expiration_days        = local.s3_log_expiration_days
  app_cloudwatch_log_expiration_days   = local.cloudwatch_log_expiration_days
  alarms_sns_topic_arn                 = module.notifications.alarms_sns_topic_arn
}

module "guardduty" {
  source = "../modules/guardduty"

  aws_security_topic_arn = module.notifications.security_sns_topic_arn
}

module "cloudtrail" {
  source                               = "../modules/cloudtrail"
  environment                          = local.environment
  include_data_events_for_bucket_names = ["data-collection-service-tfstate-production"]
  cloudwatch_log_expiration_days       = local.cloudwatch_log_expiration_days
  s3_log_expiration_days               = 90 # We're mostly interested in the CloudWatch logs, the central DLUHC account keeps a CloudTrail in S3 for security investigations
}

module "iam_roles" {
  source = "../modules/iam_roles"

  organisation_account_id = local.organisation_account_id
  environment             = local.environment
  session_manager_key_arn = module.session_manager_config.session_manager_key_arn
}

module "session_manager_config" {
  source                         = "../modules/session_manager_config"
  environment                    = local.environment
  cloudwatch_log_expiration_days = local.cloudwatch_log_expiration_days
}

module "account_security" {
  source                  = "../modules/account_security"
  organisation_account_id = local.organisation_account_id
}

module "notifications" {
  source                    = "../modules/notifications"
  environment               = local.environment
  alarm_sns_topic_emails    = local.all_notifications_email_addresses
  security_sns_topic_emails = local.all_notifications_email_addresses
}

moved {
  from = aws_lb_listener.auth
  to   = module.public_albs.aws_lb_listener.auth
}

module "auth_internal_alb" {
  source = "../modules/auth_internal_alb"

  auth_domain     = "auth.delta.${var.primary_domain}"
  certificate_arn = module.communities_only_ssl_certs.alb_certs["keycloak"].arn
  environment     = local.environment
  subnet_ids      = module.networking.auth_service_private_subnets.*.id
  vpc             = module.networking.vpc
}
