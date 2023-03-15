variable "delta_website" {
  type = object({
    cloudfront_distribution_id = string
    alb_arn_suffix             = string
    instance_metric_namespace  = string
  })
}

variable "delta_api" {
  type = object({
    cloudfront_distribution_id = string
    alb_arn_suffix             = string
    instance_metric_namespace  = string
  })
}

variable "keycloak" {
  type = object({
    cloudfront_distribution_id = string
    alb_arn_suffix             = string
    instance_metric_namespace  = string
  })
}

variable "cpm" {
  type = object({
    cloudfront_distribution_id = string
    alb_arn_suffix             = string
    instance_metric_namespace  = string
  })
}

variable "jaspersoft" {
  type = object({
    cloudfront_distribution_id = string
    alb_arn_suffix             = string
    instance_metric_namespace  = string
  })
}

variable "environment" {
  type = string
}

variable "alarms_sns_topic_arn" {
  type = string
}

# us-east-1 for CloudFront alarms
variable "alarms_sns_topic_global_arn" {
  type = string
}
