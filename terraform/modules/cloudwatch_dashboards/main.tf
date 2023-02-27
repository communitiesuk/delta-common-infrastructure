module "website_dashboard" {
  source                     = "../cloudwatch_dashboard"
  dashboard_name             = var.delta_dashboard.dashboard_name
  alb_arn_suffix             = var.delta_dashboard.alb_arn_suffix
  cloudfront_alarms          = var.delta_dashboard.cloudfront_alarms
  cloudfront_distribution_id = var.delta_dashboard.cloudfront_distribution_id
  instance_metric_namespace  = var.delta_dashboard.instance_metric_namespace
}

module "api_dashboard" {
  source                     = "../cloudwatch_dashboard"
  dashboard_name             = var.api_dashboard.dashboard_name
  alb_arn_suffix             = var.api_dashboard.alb_arn_suffix
  cloudfront_alarms          = var.api_dashboard.cloudfront_alarms
  cloudfront_distribution_id = var.api_dashboard.cloudfront_distribution_id
  instance_metric_namespace  = var.api_dashboard.instance_metric_namespace
}

module "keycloak_dashboard" {
  source                     = "../cloudwatch_dashboard"
  dashboard_name             = var.keycloak_dashboard.dashboard_name
  alb_arn_suffix             = var.keycloak_dashboard.alb_arn_suffix
  cloudfront_alarms          = var.keycloak_dashboard.cloudfront_alarms
  cloudfront_distribution_id = var.keycloak_dashboard.cloudfront_distribution_id
  instance_metric_namespace  = var.keycloak_dashboard.instance_metric_namespace
}

module "cpm_dashboard" {
  source                     = "../cloudwatch_dashboard"
  dashboard_name             = var.cpm_dashboard.dashboard_name
  alb_arn_suffix             = var.cpm_dashboard.alb_arn_suffix
  cloudfront_alarms          = var.cpm_dashboard.cloudfront_alarms
  cloudfront_distribution_id = var.cpm_dashboard.cloudfront_distribution_id
  instance_metric_namespace  = var.cpm_dashboard.instance_metric_namespace
}

module "jaspersoft_dashboard" {
  source                     = "../cloudwatch_dashboard"
  dashboard_name             = var.jaspersoft_dashboard.dashboard_name
  alb_arn_suffix             = var.jaspersoft_dashboard.alb_arn_suffix
  cloudfront_alarms          = var.jaspersoft_dashboard.cloudfront_alarms
  cloudfront_distribution_id = var.jaspersoft_dashboard.cloudfront_distribution_id
  instance_metric_namespace  = var.jaspersoft_dashboard.instance_metric_namespace
}

