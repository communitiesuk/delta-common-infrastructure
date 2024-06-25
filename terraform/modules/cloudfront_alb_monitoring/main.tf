# Note that the MarkLogic dashboard is at terraform/modules/marklogic/monitoring_dashboard.tf

module "website_cloudfront_alb_monitoring" {
  source                        = "../cloudfront_alb_monitoring_instance"
  alb_arn_suffix                = var.delta_website.alb_arn_suffix
  cloudfront_distribution_id    = var.delta_website.cloudfront_distribution_id
  instance_metric_namespace     = var.delta_website.instance_metric_namespace
  alarms_sns_topic_arn          = var.alarms_sns_topic_arn
  alarms_sns_topic_global_arn   = var.alarms_sns_topic_global_arn
  security_sns_topic_global_arn = var.security_sns_topic_global_arn
  enable_aws_shield_alarms      = var.enable_aws_shield_alarms
  prefix                        = "${var.environment}-delta-website"

  cloudfront_p90_origin_latency_high_alarm_threshold_ms     = 10000
  cloudfront_average_origin_latency_high_alarm_threshold_ms = 6000
  alb_target_client_error_rate_alarm_threshold_percent      = 20
}

module "api_cloudfront_alb_monitoring" {
  source                        = "../cloudfront_alb_monitoring_instance"
  alb_arn_suffix                = var.delta_api.alb_arn_suffix
  cloudfront_distribution_id    = var.delta_api.cloudfront_distribution_id
  instance_metric_namespace     = var.delta_api.instance_metric_namespace
  alarms_sns_topic_arn          = var.alarms_sns_topic_arn
  alarms_sns_topic_global_arn   = var.alarms_sns_topic_global_arn
  security_sns_topic_global_arn = var.security_sns_topic_global_arn
  enable_aws_shield_alarms      = var.enable_aws_shield_alarms
  prefix                        = "${var.environment}-delta-api"

  cloudfront_average_origin_latency_high_alarm_threshold_ms = 60000
}

module "keycloak_cloudfront_alb_monitoring" {
  source                        = "../cloudfront_alb_monitoring_instance"
  alb_arn_suffix                = var.keycloak.alb_arn_suffix
  cloudfront_distribution_id    = var.keycloak.cloudfront_distribution_id
  instance_metric_namespace     = var.keycloak.instance_metric_namespace
  alarms_sns_topic_arn          = var.alarms_sns_topic_arn
  alarms_sns_topic_global_arn   = var.alarms_sns_topic_global_arn
  security_sns_topic_global_arn = var.security_sns_topic_global_arn
  enable_aws_shield_alarms      = var.enable_aws_shield_alarms
  prefix                        = "${var.environment}-keycloak"

  alb_target_client_error_rate_alarm_threshold_count   = 15
}

module "cpm_cloudfront_alb_monitoring" {
  source                        = "../cloudfront_alb_monitoring_instance"
  alb_arn_suffix                = var.cpm.alb_arn_suffix
  cloudfront_distribution_id    = var.cpm.cloudfront_distribution_id
  instance_metric_namespace     = var.cpm.instance_metric_namespace
  alarms_sns_topic_arn          = var.alarms_sns_topic_arn
  alarms_sns_topic_global_arn   = var.alarms_sns_topic_global_arn
  security_sns_topic_global_arn = var.security_sns_topic_global_arn
  enable_aws_shield_alarms      = var.enable_aws_shield_alarms
  prefix                        = "${var.environment}-cpm"

  cloudfront_average_origin_latency_high_alarm_threshold_ms = 60000
}
