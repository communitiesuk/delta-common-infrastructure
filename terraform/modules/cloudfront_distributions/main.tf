module "access_logs_bucket" {
  source          = "../cloudfront_access_logs_bucket"
  environment     = var.environment
  expiration_days = 180
}

module "default_waf" {
  source           = "../waf"
  log_group_suffix = "default-${var.environment}"
  prefix           = "${var.environment}-default-"
}

module "delta_website_waf" {
  source           = "../waf"
  prefix           = "${var.environment}-delta-website-"
  log_group_suffix = "delta-website-${var.environment}"
  # Orbeon triggers this rule
  excluded_rules = ["CrossSiteScripting_BODY"]
}

module "cpm_waf" {
  source           = "../waf"
  prefix           = "${var.environment}-cpm-"
  log_group_suffix = "cpm-${var.environment}"
  # At least some e-claims POST requests trigger this rule 
  excluded_rules = ["CrossSiteScripting_BODY"]
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
}

module "api_cloudfront" {
  source                         = "../cloudfront_distribution"
  prefix                         = "delta-api-${var.environment}-"
  access_logs_bucket_domain_name = module.access_logs_bucket.bucket_domain_name
  access_logs_prefix             = "delta-api"
  waf_acl_arn                    = module.default_waf.acl_arn
  cloudfront_key                 = var.api.alb.cloudfront_key
  origin_domain                  = var.api.alb.dns_name
  cloudfront_domain              = var.api.domain
}

module "keycloak_cloudfront" {
  source                         = "../cloudfront_distribution"
  prefix                         = "keycloak-${var.environment}-"
  access_logs_bucket_domain_name = module.access_logs_bucket.bucket_domain_name
  access_logs_prefix             = "keycloak"
  waf_acl_arn                    = module.default_waf.acl_arn
  cloudfront_key                 = var.keycloak.alb.cloudfront_key
  origin_domain                  = var.keycloak.alb.dns_name
  cloudfront_domain              = var.keycloak.domain
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
}

module "jaspersoft_cloudfront" {
  source                         = "../cloudfront_distribution"
  prefix                         = "jaspersoft-${var.environment}-"
  access_logs_bucket_domain_name = module.access_logs_bucket.bucket_domain_name
  access_logs_prefix             = "jaspersoft"
  waf_acl_arn                    = module.default_waf.acl_arn
  cloudfront_key                 = var.jaspersoft.alb.cloudfront_key
  origin_domain                  = var.jaspersoft.alb.dns_name
  cloudfront_domain              = var.jaspersoft.domain
}
