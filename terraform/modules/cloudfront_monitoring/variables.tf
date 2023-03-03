variable "prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "alarms_sns_topic_global_arn" {
  description = "SNS topic ARN to send alarm notifications to"
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "Cloudfront distribution id to monitor"
  type        = string
}

variable "server_error_rate_alarm_threshold_percent" {
  description = "Threshold to trigger server error (5xx) alarm in percentage points"
  type        = number
}

variable "client_error_rate_alarm_threshold_percent" {
  description = "Threshold to trigger client error (4xx) alarm in percentage points"
  type        = number
}

variable "origin_latency_high_alarm_threshold_ms" {
  description = "Threshold to trigger alarm in milliseconds"
  type        = number
  default     = 10000
}

variable "alarm_evaluation_periods" {
  description = "How many 300s periods must fail before the alarm triggers"
  type        = number
  default     = 2
}

variable "metric_period_seconds" {
  description = "Metric sampling period in seconds"
  # Note that
  # - for basic metrics, this needs to be >= 300s
  # - for detailed metrics, this needs to be >=60s
  type    = number
  default = 300
}
