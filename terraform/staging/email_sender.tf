# Enable after building email-sender/dist/email-sender.zip.
variable "email_sender_enabled" {
  type    = bool
  default = false
}
variable "email_notify_api_key_secret_arn" {
  type    = string
  default = ""
}
variable "email_notify_template_ids" {
  type    = map(string)
  default = {}
}
module "email_sender" {
  count                     = var.email_sender_enabled ? 1 : 0
  source                    = "../modules/email_sender"
  environment               = local.environment
  backend                   = "notify"
  publisher_role_name       = module.marklogic.instance_iam_role
  alarms_sns_topic_arn      = module.notifications.alarms_sns_topic_arn
  lambda_package            = "${path.module}/../../email-sender/dist/email-sender.zip"
  notify_api_key_secret_arn = var.email_notify_api_key_secret_arn
  notify_template_ids       = var.email_notify_template_ids
}
output "email_queue_url" {
  value = try(module.email_sender[0].queue_url, null)
}
