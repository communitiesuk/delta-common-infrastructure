module "access_logs_bucket" {
  source          = "../cloudfront_access_logs_bucket"
  environment     = var.environment
  expiration_days = 180
}

module "jaspersoft_waf" {
  source            = "../waf"
  log_group_suffix  = "jaspersoft-${var.environment}"
  prefix            = "${var.environment}-jaspersoft-"
  per_ip_rate_limit = var.waf_per_ip_rate_limit
  # Editing queries triggers these rules
  excluded_rules = ["CrossSiteScripting_BODY", "GenericLFI_BODY"]
  ip_allowlist   = var.jaspersoft.ip_allowlist
}

module "delta_website_waf" {
  source            = "../waf"
  prefix            = "${var.environment}-delta-website-"
  log_group_suffix  = "delta-website-${var.environment}"
  per_ip_rate_limit = var.waf_per_ip_rate_limit
  # Orbeon triggers this rule
  excluded_rules = ["CrossSiteScripting_BODY"]
  ip_allowlist   = var.delta.ip_allowlist
}

module "cpm_waf" {
  source            = "../waf"
  prefix            = "${var.environment}-cpm-"
  log_group_suffix  = "cpm-${var.environment}"
  per_ip_rate_limit = var.waf_per_ip_rate_limit
  # At least some e-claims POST requests trigger this rule
  excluded_rules = ["CrossSiteScripting_BODY"]
  ip_allowlist   = var.cpm.ip_allowlist
}

module "api_auth_waf" {
  source            = "../waf"
  prefix            = "${var.environment}-delta-api-"
  log_group_suffix  = "delta-api-${var.environment}"
  per_ip_rate_limit = var.waf_per_ip_rate_limit
  # XSS not issue for API
  excluded_rules = ["CrossSiteScripting_BODY", "CrossSiteScripting_COOKIE", "CrossSiteScripting_QUERYARGUMENTS", "CrossSiteScripting_URIPATH"]
  ip_allowlist   = var.api.ip_allowlist
}

module "delta_cloudfront" {
  source                         = "../cloudfront_distribution"
  prefix                         = "delta-${var.environment}-"
  access_logs_bucket_domain_name = module.access_logs_bucket.bucket_domain_name
  access_logs_prefix             = "delta"
  waf_acl_arn                    = module.delta_website_waf.acl_arn
  cloudfront_key                 = var.delta.alb.cloudfront_key
  origin_domain                  = var.delta.alb.dns_name
  cloudfront_domain              = var.delta.domain
  is_ipv6_enabled                = var.delta.ip_allowlist == null
  geo_restriction_enabled        = var.delta.disable_geo_restriction != true
  apply_aws_shield               = var.apply_aws_shield
}

module "api_cloudfront" {
  source                         = "../api_cloudfront"
  prefix                         = "delta-api-${var.environment}-"
  access_logs_bucket_domain_name = module.access_logs_bucket.bucket_domain_name
  access_logs_prefix             = "delta-api"
  waf_acl_arn                    = module.api_auth_waf.acl_arn
  cloudfront_key                 = var.api.alb.cloudfront_key
  origin_domain                  = var.api.alb.dns_name
  cloudfront_domain              = var.api.domain
  is_ipv6_enabled                = var.api.ip_allowlist == null
  geo_restriction_enabled        = var.api.disable_geo_restriction != true
  environment                    = var.environment
  apply_aws_shield               = var.apply_aws_shield
}

module "keycloak_cloudfront" {
  source                         = "../cloudfront_distribution"
  prefix                         = "keycloak-${var.environment}-"
  access_logs_bucket_domain_name = module.access_logs_bucket.bucket_domain_name
  access_logs_prefix             = "keycloak"
  waf_acl_arn                    = module.api_auth_waf.acl_arn
  cloudfront_key                 = var.keycloak.alb.cloudfront_key
  origin_domain                  = var.keycloak.alb.dns_name
  cloudfront_domain              = var.keycloak.domain
  is_ipv6_enabled                = var.keycloak.ip_allowlist == null
  geo_restriction_enabled        = var.keycloak.disable_geo_restriction != true
  apply_aws_shield               = var.apply_aws_shield
}

module "cpm_cloudfront" {
  source                         = "../cloudfront_distribution"
  prefix                         = "cpm-${var.environment}-"
  access_logs_bucket_domain_name = module.access_logs_bucket.bucket_domain_name
  access_logs_prefix             = "cpm"
  waf_acl_arn                    = module.cpm_waf.acl_arn
  cloudfront_key                 = var.cpm.alb.cloudfront_key
  origin_domain                  = var.cpm.alb.dns_name
  cloudfront_domain              = var.cpm.domain
  is_ipv6_enabled                = var.cpm.ip_allowlist == null
  geo_restriction_enabled        = var.cpm.disable_geo_restriction != true
  apply_aws_shield               = var.apply_aws_shield
}

module "jaspersoft_cloudfront" {
  source                         = "../cloudfront_distribution"
  prefix                         = "jaspersoft-${var.environment}-"
  access_logs_bucket_domain_name = module.access_logs_bucket.bucket_domain_name
  access_logs_prefix             = "jaspersoft"
  waf_acl_arn                    = module.jaspersoft_waf.acl_arn
  cloudfront_key                 = var.jaspersoft.alb.cloudfront_key
  origin_domain                  = var.jaspersoft.alb.dns_name
  cloudfront_domain              = var.jaspersoft.domain
  is_ipv6_enabled                = var.jaspersoft.ip_allowlist == null
  geo_restriction_enabled        = var.jaspersoft.disable_geo_restriction != true
  apply_aws_shield               = var.apply_aws_shield
}
