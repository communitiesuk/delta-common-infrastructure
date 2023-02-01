variable "environment" {
  type = string
}

variable "cloudwatch_log_expiration_days" {
  type = number
}

# Note that port forwarding sessions do not get logged
module "session_manager_log_group" {
  source = "../encrypted_log_groups"

  kms_key_alias_name = "session-manager-logs"
  log_group_names    = ["session-manager-logs"]
  retention_days     = var.cloudwatch_log_expiration_days
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
      runAsEnabled                = false
      idleSessionTimeout          = "20"
      maxSessionDuration          = ""
    }
  })
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
resource "aws_kms_key" "main" {
  enable_key_rotation = true
  description         = "Encryption of SSM Session Manager sessions"
}

resource "aws_kms_alias" "main" {
  name          = "alias/session-manager-key"
  target_key_id = aws_kms_key.main.key_id
}


#tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_policy" "main" {
  name        = "session-manager-policy"
  description = "Allows instances to start Session Manager sessions and send logs to CloudWath"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = [aws_kms_key.main.arn]
      },
      {
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:PutLogEvents",
        ]
        Effect   = "Allow"
        Resource = ["${module.session_manager_log_group.log_group_arns[0]}:*"]
      }
    ]
  })
}

output "policy_arn" {
  value = aws_iam_policy.main.arn
}

output "session_manager_key_arn" {
  value = aws_kms_key.main.arn
}
