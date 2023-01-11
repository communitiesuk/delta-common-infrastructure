variable "environment" {
  type = string
}

module "session_manager_log_group" {
  source = "../encrypted_log_groups"

  kms_key_alias_name = "session-manager-logs"
  log_group_names    = ["session-manager-logs"]
}

resource "aws_ssm_document" "session_manager_prefs" {
  name            = "SSM-SessionManagerRunShell"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Document to hold regional settings for Session Manager"
    sessionType   = "Standard_Stream"
    inputs = {
      kmsKeyId                    = aws_kms_key.main.key_id
      cloudWatchLogGroupName      = module.session_manager_log_group.log_group_names[0]
      cloudWatchEncryptionEnabled = true
      cloudWatchStreamingEnabled  = true
      runAsEnabled                = true
    }
  })
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
resource "aws_kms_key" "main" {
  enable_key_rotation = true
  description         = "Encryption of SSM Session Manager sessions"
  # policy = templatefile("${path.module}/kms_policy.json", {
  #   account_id      = data.aws_caller_identity.current.account_id
  #   region          = data.aws_region.current.name
  # })
}

resource "aws_kms_alias" "main" {
  name          = "alias/session-manager-key"
  target_key_id = aws_kms_key.main.key_id
}

output "kms_key_arn" {
  value = aws_kms_key.main.arn
}