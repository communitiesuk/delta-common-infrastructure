# Enable after building email-sender/dist/email-sender.zip.
variable "email_sender_enabled" {
  type    = bool
  default = true
}
variable "email_notify_api_key_secret_arn" {
  type    = string
  default = "arn:aws:secretsmanager:eu-west-1:486283582667:secret:delta-notify-api-key-staging-E8ODF2"
}
variable "email_notify_template_ids" {
  type = map(string)
  default = {
    "cpm/approved_transactions_summary" = "2f18a006-be39-4560-96d1-d749531b6b9f"
    "delta/collection_instance_release" = "73f8d2cd-3da0-4f1a-a4e4-7150395bfb56"
    "delta/large_download_ready"        = "c466ad16-c6f5-41db-b3fb-1bc4748bb719"
  }
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
output "email_attachment_bucket_url" {
  value = try(module.email_sender[0].attachment_bucket_url, null)
}
