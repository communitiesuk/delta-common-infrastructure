variable "delta_dashboard" {
  type = object({
    dashboard_name             = string
    cloudfront_distribution_id = string
    cloudfront_alarms          = list(string)
    alb_arn_suffix             = string
    instance_metric_namespace  = string
  })
}

variable "api_dashboard" {
  type = object({
    dashboard_name             = string
    cloudfront_distribution_id = string
    cloudfront_alarms          = list(string)
    alb_arn_suffix             = string
    instance_metric_namespace  = string
  })
}

variable "keycloak_dashboard" {
  type = object({
    dashboard_name             = string
    cloudfront_distribution_id = string
    cloudfront_alarms          = list(string)
    alb_arn_suffix             = string
    instance_metric_namespace  = string
  })
}

variable "cpm_dashboard" {
  type = object({
    dashboard_name             = string
    cloudfront_distribution_id = string
    cloudfront_alarms          = list(string)
    alb_arn_suffix             = string
    instance_metric_namespace  = string
  })
}
