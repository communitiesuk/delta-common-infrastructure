variable "dashboard_name" {
  description = "name for the dashboard"
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "Id of Cloudfront distribution"
  type        = string
}

variable "cloudfront_alarms" {
  description = "Alarm arns from Cloudfront Distribution"
  type        = list(string)
}

variable "alb_arn_suffix" {
  description = "Arn suffix from ALB"
  type        = string
}

variable "instance_metric_namespace" {
  description = "Namespace of metrics recorded by cloudwatch agent"
  type        = string
  default     = null
}
