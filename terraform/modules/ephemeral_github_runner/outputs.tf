output "webhook_url" {
  description = "Payload URL for the delta-marklogic-deploy Workflow jobs repository webhook."
  value       = module.runners.webhook.endpoint
}

output "runner_log_groups" {
  description = "CloudWatch log groups for the ephemeral EC2 runners."
  value       = module.runners.runners.runners_log_groups[*].name
}

output "runner_binaries_syncer_name" {
  description = "Lambda to invoke before enabling the webhook if the runner binary has not synced yet."
  value       = module.runners.binaries_syncer.lambda.function_name
}

output "label" {
  value = local.label
}

output "parameter_names" {
  value = { for key, parameter in local.parameters : key => parameter.name }
}
