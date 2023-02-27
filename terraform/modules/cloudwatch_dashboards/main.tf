module "delta_dashboard" {
  source = "../cloudwatch_dashboard"
  dashboard_name = "${var.environment}-website"
  alb_arn_suffix = var.delta_alb_arn_suffix
  cloudfront_alarms = var.delta_cloudfront_alarms
  cloudfront_distribution_id = var.delta_cloudfront_distribution_id
  instance_metric_namespace = "${var.environment}/DeltaServers"
}
