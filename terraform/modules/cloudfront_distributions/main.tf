module "access_logs_bucket" {
  source          = "../cloudfront_access_logs_bucket"
  environment     = var.environment
  expiration_days = var.cloudfront_access_s3_log_expiration_days
}

module "delta_website_waf" {
  source            = "../waf"
  prefix            = "${var.environment}-delta-website-"
  log_group_suffix  = "delta-website-${var.environment}"
  per_ip_rate_limit = var.waf_per_ip_rate_limit
  # Orbeon triggers this rule
  excluded_rules = [
    "CrossSiteScripting_BODY",      # Sometimes blocks File uploads
    "GenericLFI_BODY",              # Sometimes blocks Excel uploads
    "SizeRestrictions_QUERYSTRING", # To allow long query strings - fix for MSD-80376
  ]
  ip_allowlist                   = var.delta.ip_allowlist
  cloudwatch_log_expiration_days = var.waf_cloudwatch_log_expiration_days
  alarms_sns_topic_global_arn    = var.alarms_sns_topic_global_arn
  security_sns_topic_global_arn  = var.security_sns_topic_global_arn
}

module "cpm_waf" {
  source            = "../waf"
  prefix            = "${var.environment}-cpm-"
  log_group_suffix  = "cpm-${var.environment}"
  per_ip_rate_limit = var.waf_per_ip_rate_limit
  # At least some e-claims POST requests trigger this rule
  excluded_rules                 = ["CrossSiteScripting_BODY"]
  ip_allowlist                   = var.cpm.ip_allowlist
  cloudwatch_log_expiration_days = var.waf_cloudwatch_log_expiration_days
  alarms_sns_topic_global_arn    = var.alarms_sns_topic_global_arn
  security_sns_topic_global_arn  = var.security_sns_topic_global_arn
}

module "api_waf" {
  source            = "../waf"
  prefix            = "${var.environment}-delta-api-"
  log_group_suffix  = "delta-api-${var.environment}"
  per_ip_rate_limit = var.waf_per_ip_rate_limit
  # XSS not issue for API
  excluded_rules                 = ["CrossSiteScripting_BODY", "CrossSiteScripting_COOKIE", "CrossSiteScripting_QUERYARGUMENTS", "CrossSiteScripting_URIPATH"]
  ip_allowlist                   = var.api.ip_allowlist
  cloudwatch_log_expiration_days = var.waf_cloudwatch_log_expiration_days
  alarms_sns_topic_global_arn    = var.alarms_sns_topic_global_arn
  security_sns_topic_global_arn  = var.security_sns_topic_global_arn
}

moved {
  //noinspection HILUnresolvedReference
  from = module.api_auth_waf
  to   = module.api_waf
}

module "auth_waf" {
  source                         = "../waf"
  prefix                         = "${var.environment}-auth-"
  log_group_suffix               = "auth-${var.environment}"
  per_ip_rate_limit              = var.auth_waf_per_ip_rate_limit
  excluded_rules                 = ["CrossSiteScripting_BODY"]
  ip_allowlist                   = var.api.ip_allowlist
  ip_allowlist_uri_path_regex    = ["^/keycloak/", "/realms/delta/", "^/delta-api/"]
  cloudwatch_log_expiration_days = var.waf_cloudwatch_log_expiration_days
  alarms_sns_topic_global_arn    = var.alarms_sns_topic_global_arn
  security_sns_topic_global_arn  = var.security_sns_topic_global_arn
}

module "delta_cloudfront" {
  source                         = "../cloudfront_website"
  prefix                         = "delta-${var.environment}-"
  access_logs_bucket_domain_name = module.access_logs_bucket.bucket_domain_name
  access_logs_prefix             = "delta"
  waf_acl_arn                    = module.delta_website_waf.acl_arn
  cloudfront_key                 = var.delta.alb.cloudfront_key
  origin_domain                  = var.delta.alb.dns_name
  cloudfront_domain              = var.delta.domain
  is_ipv6_enabled                = var.delta.ip_allowlist == null
  geo_restriction_countries      = var.delta.geo_restriction_countries
  apply_aws_shield               = var.apply_aws_shield
  origin_read_timeout            = var.delta.origin_read_timeout == null ? 60 : var.delta.origin_read_timeout
  wait_for_deployment            = var.wait_for_deployment
}

module "api_cloudfront" {
  source                         = "../cloudfront_api"
  prefix                         = "delta-api-${var.environment}-"
  access_logs_bucket_domain_name = module.access_logs_bucket.bucket_domain_name
  access_logs_prefix             = "delta-api"
  waf_acl_arn                    = module.api_waf.acl_arn
  cloudfront_key                 = var.api.alb.cloudfront_key
  origin_domain                  = var.api.alb.dns_name
  cloudfront_domain              = var.api.domain
  is_ipv6_enabled                = var.api.ip_allowlist == null
  geo_restriction_countries      = var.api.geo_restriction_countries
  environment                    = var.environment
  apply_aws_shield               = var.apply_aws_shield
  swagger_s3_log_expiration_days = var.swagger_s3_log_expiration_days
  wait_for_deployment            = var.wait_for_deployment

}

module "auth_cloudfront" {
  source                         = "../cloudfront_auth_service"
  prefix                         = "keycloak-${var.environment}-"
  access_logs_bucket_domain_name = module.access_logs_bucket.bucket_domain_name
  access_logs_prefix             = "keycloak"
  waf_acl_arn                    = module.auth_waf.acl_arn
  cloudfront_key                 = var.auth.alb.cloudfront_key
  origin_domain                  = var.auth.alb.dns_name
  cloudfront_domain              = var.auth.domain
  is_ipv6_enabled                = false
  geo_restriction_countries      = var.auth.geo_restriction_countries
  apply_aws_shield               = var.apply_aws_shield
  function_associations          = [{ event_type = "viewer-request", function_arn = aws_cloudfront_function.keycloak_request.arn }]
  wait_for_deployment            = var.wait_for_deployment
}

moved {
  //noinspection HILUnresolvedReference
  from = module.keycloak_cloudfront
  to   = module.auth_cloudfront
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
  geo_restriction_countries      = var.cpm.geo_restriction_countries
  apply_aws_shield               = var.apply_aws_shield
  origin_read_timeout            = var.cpm.origin_read_timeout == null ? 60 : var.cpm.origin_read_timeout
  wait_for_deployment            = var.wait_for_deployment
}
