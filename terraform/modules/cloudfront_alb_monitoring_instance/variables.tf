variable "cloudfront_distribution_id" {
  description = "Id of Cloudfront distribution"
  type        = string
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

variable "alb_target_server_error_rate_alarm_threshold_percent" {
  type        = number
  description = "Threshold for alarm on 5xx responses as percentage of 2xx responses, count threshold must also be met"
  default     = 5
}

variable "alb_target_server_error_rate_alarm_threshold_count" {
  type        = number
  description = "Static threshold for minimum number of 5xx responses in period to trigger alarm"
  default     = 20
}

variable "alb_target_client_error_rate_alarm_threshold_percent" {
  type        = number
  description = "Threshold for alarm on 4xx responses as percentage of 2xx responses, count threshold must also be met"
  default     = 5
}

variable "alb_target_client_error_rate_alarm_threshold_count" {
  type        = number
  description = "Static threshold for minimum number of 4xx responses in period to trigger alarm"
  default     = 30
}

variable "alarms_sns_topic_arn" {
  type = string
}

variable "prefix" {
  description = "The dashboard name and prefix for all other resources"
  type        = string

  validation {
    condition     = length(var.prefix) > 0 && !endswith(var.prefix, "-")
    error_message = "Must be non empty"
  }
}

variable "alarms_sns_topic_global_arn" {
  description = "SNS topic ARN to send alarm notifications to"
  type        = string
}

variable "cloudfront_server_error_rate_alarm_threshold_percent" {
  description = "Threshold to trigger server error (5xx) alarm in percentage points"
  type        = number
  default     = 10
}

variable "cloudfront_client_error_rate_alarm_threshold_percent" {
  description = "Threshold to trigger client error (4xx) alarm in percentage points"
  type        = number
  default     = 25 # CloudFront error rate includes geo-blocked requests
}

variable "cloudfront_average_origin_latency_high_alarm_threshold_ms" {
  description = "Threshold to trigger alarm in milliseconds"
  type        = number
  default     = 5000
}

variable "cloudfront_p90_origin_latency_high_alarm_threshold_ms" {
  description = "Optional, threshold to trigger alarm in milliseconds"
  type        = number
  default     = null
}

variable "cloudfront_metric_period_seconds" {
  description = "Metric sampling period in seconds"
  # Note that
  # - for basic metrics, this needs to be >= 300s
  # - for detailed metrics, this needs to be >=60s
  type    = number
  default = 300
}
