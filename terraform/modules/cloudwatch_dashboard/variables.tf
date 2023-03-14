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

variable "alb_target_server_error_rate_alarm_threshold_percent" {
  type        = number
  description = "Threshold for alarm on 5xx responses as percentage of 2xx responses, count threshold must also be met"
  default     = 10
}

variable "alb_target_server_error_rate_alarm_threshold_count" {
  type        = number
  description = "Static threshold for minimum number of 5xx responses in period to trigger alarm"
  default     = 20
}

variable "alb_target_client_error_rate_alarm_threshold_percent" {
  type        = number
  description = "Threshold for alarm on 4xx responses as percentage of 2xx responses, count threshold must also be met"
  default     = 20
}

variable "alb_target_client_error_rate_alarm_threshold_count" {
  type        = number
  description = "Static threshold for minimum number of 4xx responses in period to trigger alarm"
  default     = 50
}

variable "alarms_sns_topic_arn" {
  type = string
}
