variable "environment" {
  description = "test, staging or production"
  type        = string
}

variable "delta_cloudfront_alarms" {
  description = "Alarm arns from Delta Cloudfront Distribution"
  type        = list(string)
}

variable "delta_alb_arn_suffix" {
  description = "Arn suffix from ALB"
  type        = string
}

variable "delta_cloudfront_distribution_id" {
  description = "Id of Delta Cloudfront distribution"
  type        = string
}

