# All public ALBs.
# We need to give DLUHC the CloudFront distributions to create DNS records, and CloudFront distributions need an origin,
# so we have these as a separate module and then each app can define its own listeners and targets.

variable "vpc" {
  type = object({
    id         = string
    cidr_block = string
  })
}

variable "environment" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

resource "random_password" "cloudfront_keys" {
  for_each = toset(["delta", "api", "keycloak", "cpm", "jaspersoft"])
  length   = 24
  special  = false
}

module "delta_alb" {
  source = "../public_alb"

  vpc                 = var.vpc
  subnet_ids          = var.subnet_ids
  prefix              = "${var.environment}-delta-site-"
  log_expiration_days = 30
}

output "delta" {
  value = {
    arn               = module.delta_alb.arn
    dns_name          = module.delta_alb.dns_name
    security_group_id = module.delta_alb.security_group_id
    cloudfront_key    = random_password.cloudfront_keys["delta"].result
  }
}

module "delta_api_alb" {
  source = "../public_alb"

  vpc                 = var.vpc
  subnet_ids          = var.subnet_ids
  prefix              = "${var.environment}-delta-api-"
  log_expiration_days = 30
}

output "delta_api" {
  value = {
    arn               = module.delta_api_alb.arn
    dns_name          = module.delta_api_alb.dns_name
    security_group_id = module.delta_api_alb.security_group_id
    cloudfront_key    = random_password.cloudfront_keys["api"].result
  }
}

module "keycloak_alb" {
  source = "../public_alb"

  vpc                 = var.vpc
  subnet_ids          = var.subnet_ids
  prefix              = "${var.environment}-keycloak-"
  log_expiration_days = 30
}

output "keycloak" {
  value = {
    arn               = module.keycloak_alb.arn
    dns_name          = module.keycloak_alb.dns_name
    security_group_id = module.keycloak_alb.security_group_id
    cloudfront_key    = random_password.cloudfront_keys["keycloak"].result
  }
}

module "cpm_alb" {
  source = "../public_alb"

  vpc                 = var.vpc
  subnet_ids          = var.subnet_ids
  prefix              = "${var.environment}-cpm-"
  log_expiration_days = 30
}

output "cpm" {
  value = {
    arn               = module.cpm_alb.arn
    dns_name          = module.cpm_alb.dns_name
    security_group_id = module.cpm_alb.security_group_id
    cloudfront_key    = random_password.cloudfront_keys["cpm"].result
  }
}

module "jaspersoft_alb" {
  source = "../public_alb"

  vpc                 = var.vpc
  subnet_ids          = var.subnet_ids
  prefix              = "${var.environment}-jaspersoft-"
  log_expiration_days = 30
}

output "jaspersoft" {
  value = {
    arn               = module.jaspersoft_alb.arn
    dns_name          = module.jaspersoft_alb.dns_name
    security_group_id = module.jaspersoft_alb.security_group_id
    cloudfront_key    = random_password.cloudfront_keys["jaspersoft"].result
  }
}
