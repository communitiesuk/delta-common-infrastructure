variable "environment" { type = string }
variable "backend" {
  type = string
  validation {
    condition     = contains(["log", "notify"], var.backend)
    error_message = "Email backend must be log or notify."
  }
}
variable "publisher_role_name" { type = string }
variable "alarms_sns_topic_arn" { type = string }
variable "lambda_package" { type = string }
variable "notify_api_key_secret_arn" {
  type    = string
  default = ""
}
variable "notify_template_ids" {
  type    = map(string)
  default = {}
}
