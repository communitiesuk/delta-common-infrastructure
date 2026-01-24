terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.72.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.2"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.6"
    }
  }

  # Requires S3 bucket & Dynamo DB to be configured, please see README.md
  backend "s3" {
    bucket         = "data-collection-service-tfstate-dev"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:eu-west-1:486283582667:key/547ae46f-f57e-45f6-bcfd-9403bed9ec75"
    dynamodb_table = "tfstate-locks"
    key            = "common-infra-staging1"
    region         = "eu-west-1"
  }

  required_version = "~> 1.9.0"
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = var.default_tags
  }
}

locals {
  environment                          = "staging1"
  organisation_account_id              = "448312965134"
  apply_aws_shield                     = false
  cloudwatch_log_expiration_days       = 60
  patch_cloudwatch_log_expiration_days = 60
  s3_log_expiration_days               = 60
  all_notifications_email_addresses    = ["delta-notifications@communities.gov.uk", "dluhc-delta-dev-cloud-aaaamwf6vajqjepih2xfrp2dqe@communities-govuk.slack.com"]
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Defined in test/main.tf for the dev AWS account
data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

# Reference existing VPC from staging environment
data "aws_vpc" "staging" {
  tags = {
    Name = "delta-vpc-staging"
  }
}

# Get all subnets in the staging VPC
data "aws_subnets" "all_staging_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.staging.id]
  }
}

# Get individual subnet details and filter for MarkLogic subnets
data "aws_subnet" "all_subnets" {
  for_each = toset(data.aws_subnets.all_staging_subnets.ids)
  id       = each.value
}

# Filter to get only MarkLogic private subnets (should be 3)
locals {
  ml_private_subnets = [
    for subnet in data.aws_subnet.all_subnets : subnet
    if can(regex("^marklogic-private-subnet-.*-staging$", subnet.tags.Name))
  ]
}

# Reference existing private DNS zone from staging
data "aws_route53_zone" "private" {
  name         = "vpc.local"
  private_zone = true
  vpc_id       = data.aws_vpc.staging.id
}

# Notifications for alarms
module "notifications" {
  source                    = "../modules/notifications"
  environment               = local.environment
  alarm_sns_topic_emails    = local.all_notifications_email_addresses
  security_sns_topic_emails = local.all_notifications_email_addresses
}

# Session Manager config - use existing shared resources from staging
data "aws_kms_key" "session_manager" {
  # Created by the staging environment
  key_id = "alias/session-manager-key"
}

data "aws_iam_policy" "session_manager_policy" {
  # Created by the staging environment
  name = "session-manager-policy"
}

locals {
  session_manager_policy_arn = data.aws_iam_policy.session_manager_policy.arn
}

# Maintenance window for MarkLogic patching
module "marklogic_patch_maintenance_window" {
  source = "../modules/maintenance_window"

  environment       = local.environment
  prefix            = "ml-instance-patching"
  schedule          = "cron(00 06 ? * TUE *)"
  subscribed_emails = local.all_notifications_email_addresses

  enabled = true
}

# Backup replication bucket
module "backup_replication_bucket" {
  source = "../modules/backup_replication_bucket"

  environment                   = local.environment
  s3_access_log_expiration_days = local.s3_log_expiration_days
  compliance_retention_days     = 28
  object_expiration_days        = 30
}

# EBS backup service
module "ebs_backup" {
  source = "../modules/ebs_backup"

  environment                          = local.environment
  ebs_backup_error_notification_emails = local.all_notifications_email_addresses
}

# MarkLogic cluster - using existing VPC and subnets from staging
module "marklogic" {
  source = "../modules/marklogic"

  default_tags                        = var.default_tags
  environment                         = local.environment
  vpc                                 = data.aws_vpc.staging
  private_subnets                     = local.ml_private_subnets
  instance_type                       = "t3a.2xlarge"
  marklogic_ami_version               = "10.0-10.2"
  private_dns = {
    zone_id     = data.aws_route53_zone.private.zone_id
    base_domain = data.aws_route53_zone.private.name
  }
  patch_maintenance_window = module.marklogic_patch_maintenance_window
  data_volume = {
    size_gb                = 200
    iops                   = 3000
    throughput_MiB_per_sec = 250
  }

  extra_instance_policy_arn               = local.session_manager_policy_arn
  app_cloudwatch_log_expiration_days      = local.cloudwatch_log_expiration_days
  patch_cloudwatch_log_expiration_days    = local.patch_cloudwatch_log_expiration_days
  config_s3_log_expiration_days           = local.s3_log_expiration_days
  dap_export_s3_log_expiration_days       = local.s3_log_expiration_days
  s151_export_s3_log_expiration_days      = local.s3_log_expiration_days
  backup_s3_log_expiration_days           = local.s3_log_expiration_days
  alarms_sns_topic_arn                    = module.notifications.alarms_sns_topic_arn
  data_disk_usage_alarm_threshold_percent = 70
  dap_external_role_arns                  = var.dap_external_role_arns
  s151_external_canonical_users           = var.s151_external_canonical_users
  dap_job_notification_emails             = local.all_notifications_email_addresses
  backup_replication_bucket               = module.backup_replication_bucket.bucket
  ebs_backup_role_arn                     = module.ebs_backup.role_arn
  ebs_backup_completed_sns_topic_arn      = module.ebs_backup.sns_topic_arn
  iam_github_openid_connect_provider_arn  = data.aws_iam_openid_connect_provider.github.arn
  ses_deploy_secret_arns = ["arn:aws:kms:eu-west-1:486283582667:key/*"]
  cluster_suffix          = "-staging1"
  create_dns_record       = false # We create our own DNS record (marklogic1.vpc.local) below
}

# Create separate Route53 record for marklogic1.vpc.local
resource "aws_route53_record" "marklogic1_internal_nlb" {
  zone_id = data.aws_route53_zone.private.zone_id
  name    = "marklogic1.${data.aws_route53_zone.private.name}"
  type    = "A"

  alias {
    name                   = module.marklogic.ml_lb_dns_name
    zone_id                = module.marklogic.ml_lb_zone_id
    evaluate_target_health = false
  }
}
