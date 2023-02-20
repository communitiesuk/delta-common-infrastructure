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

variable "origin_latency_high_alarm_threshold_ms" {
  description = "threshold to trigger alarm in milliseconds"
  type        = number
  default     = 10000
}
