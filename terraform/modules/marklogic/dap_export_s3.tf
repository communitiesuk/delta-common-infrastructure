locals {
  delta_export_path                    = "/delta/export"
  latest_export_files_lifespan_in_days = 30
  dap_export_external_access = {
    for access in var.dap_export_external_access : access.name => access
  }
}

module "dap_export_bucket" {
  source                             = "../s3_bucket"
  bucket_name                        = "dluhc-delta-dap-export-${var.environment}"
  access_log_bucket_name             = "dluhc-delta-dap-export-access-logs-${var.environment}"
  access_s3_log_expiration_days      = var.dap_export_s3_log_expiration_days
  noncurrent_version_expiration_days = null
  policy                             = data.aws_iam_policy_document.allow_access_from_dap.json
}

data "aws_iam_policy_document" "allow_access_from_dap" {
  statement {
    principals {
      type        = "AWS"
      identifiers = var.dap_external_role_arns
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketLocation"
    ]

    resources = [
      module.dap_export_bucket.bucket_arn,
      "${module.dap_export_bucket.bucket_arn}/latest/*",
    ]
  }
  statement {
    sid    = "DenyExternalRoleArnsAccessToS151Folder"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = var.dap_external_role_arns
    }
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${module.dap_export_bucket.bucket_arn}/latest/s151*",
    ]
  }
  dynamic "statement" {
    for_each = length(var.s151_external_canonical_users) > 0 ? [1] : []
    content {
      sid    = "AllowExternalBucketAccess"
      effect = "Allow"
      principals {
        type        = "CanonicalUser"
        identifiers = var.s151_external_canonical_users
      }
      actions = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      resources = [
        module.dap_export_bucket.bucket_arn,
        "${module.dap_export_bucket.bucket_arn}/latest/s151*",
      ]
    }
  }
}

resource "aws_iam_user" "dap_export_external" {
  for_each = local.dap_export_external_access

  name = "${each.key}-dap-export-${var.environment}"

  lifecycle {
    ignore_changes = [tags, tags_all] # AWS uses tags for access key descriptions
  }
}

data "aws_iam_policy_document" "dap_export_external" {
  for_each = local.dap_export_external_access

  statement {
    sid = "AllowLatestObjectReadFromApprovedIps"
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "${module.dap_export_bucket.bucket_arn}/latest/*",
    ]

    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = each.value.allowed_cidrs
    }
  }

  statement {
    sid = "AllowBucketMetadataReadFromApprovedIps"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetEncryptionConfiguration",
    ]
    resources = [
      module.dap_export_bucket.bucket_arn,
    ]

    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = each.value.allowed_cidrs
    }
  }

  statement {
    sid = "AllowLatestBucketListFromApprovedIps"
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      module.dap_export_bucket.bucket_arn,
    ]

    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = each.value.allowed_cidrs
    }

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        "latest",
        "latest/*",
      ]
    }
  }

  statement {
    sid    = "DenyS151ObjectRead"
    effect = "Deny"
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "${module.dap_export_bucket.bucket_arn}/latest/s151*",
    ]
  }
}

resource "aws_iam_policy" "dap_export_external" {
  for_each = local.dap_export_external_access

  name        = "${each.key}-dap-export-${var.environment}"
  description = "Allows ${each.key} to read non-S151 DAP export objects"
  policy      = data.aws_iam_policy_document.dap_export_external[each.key].json
}

resource "aws_iam_user_policy_attachment" "dap_export_external" {
  for_each = local.dap_export_external_access

  user       = aws_iam_user.dap_export_external[each.key].name
  policy_arn = aws_iam_policy.dap_export_external[each.key].arn
}

resource "aws_kms_key" "dap_export_external_secret" {
  for_each = local.dap_export_external_access

  description         = "dap-export-${each.key}-${var.environment}"
  enable_key_rotation = true

  tags = {
    "terraform-plan-read" = true
  }
}

resource "aws_kms_alias" "dap_export_external_secret" {
  for_each = local.dap_export_external_access

  name          = "alias/dap-export-${each.key}-${var.environment}"
  target_key_id = aws_kms_key.dap_export_external_secret[each.key].key_id
}

resource "aws_secretsmanager_secret" "dap_export_external" {
  for_each = local.dap_export_external_access

  name                    = "tf-dap-export-${each.key}-${var.environment}"
  description             = "Managed by Terraform, do not update manually"
  kms_key_id              = aws_kms_key.dap_export_external_secret[each.key].arn
  recovery_window_in_days = 0

  tags = {
    "terraform-plan-read" = true
  }
}

resource "aws_secretsmanager_secret_version" "dap_export_external" {
  for_each = local.dap_export_external_access

  secret_id = aws_secretsmanager_secret.dap_export_external[each.key].id
  secret_string = jsonencode({
    access_key_id     = ""
    secret_access_key = ""
    region            = data.aws_region.current.name
    bucket            = module.dap_export_bucket.bucket
    prefix            = "latest/"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

data "archive_file" "dap_export_secret_rotation" {
  type        = "zip"
  source_file = "${path.module}/dap_export_secret_rotation.py"
  output_path = "${path.module}/dap_export_secret_rotation.zip"
}

module "dap_export_secret_rotation_log_group" {
  for_each = local.dap_export_external_access

  source         = "../encrypted_log_groups"
  retention_days = var.patch_cloudwatch_log_expiration_days

  kms_key_alias_name = "dap-export-secret-rotation-${each.key}-${var.environment}"
  log_group_names    = ["/aws/lambda/dap-export-secret-rotation-${each.key}-${var.environment}"]
}

resource "aws_security_group" "dap_export_secret_rotation_lambda" {
  for_each = local.dap_export_external_access

  name        = "dap-export-secret-rotation-${each.key}-${var.environment}"
  description = "Security group for DAP export secret rotation Lambda"
  vpc_id      = var.vpc.id

  egress {
    description = "Allow HTTPS egress within the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc.cidr_block]
  }
}

resource "aws_iam_role" "dap_export_secret_rotation" {
  for_each = local.dap_export_external_access

  name = "dap-export-secret-rotation-${each.key}-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

data "aws_iam_policy_document" "dap_export_secret_rotation" {
  for_each = local.dap_export_external_access

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["${module.dap_export_secret_rotation_log_group[each.key].log_group_arns[0]}:*"]
  }

  statement {
    actions = [
      "iam:CreateAccessKey",
      "iam:DeleteAccessKey",
      "iam:ListAccessKeys",
    ]
    resources = [aws_iam_user.dap_export_external[each.key].arn]
  }

  statement {
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecretVersionStage",
    ]
    resources = [aws_secretsmanager_secret.dap_export_external[each.key].arn]
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey",
    ]
    resources = [
      aws_kms_key.dap_export_external_secret[each.key].arn,
      module.dap_export_secret_rotation_log_group[each.key].kms_key_arn,
    ]
  }
}

resource "aws_iam_policy" "dap_export_secret_rotation" {
  for_each = local.dap_export_external_access

  name        = "dap-export-secret-rotation-${each.key}-${var.environment}"
  description = "Allows rotation of DAP export access keys for ${each.key}"
  policy      = data.aws_iam_policy_document.dap_export_secret_rotation[each.key].json
}

resource "aws_iam_role_policy_attachment" "dap_export_secret_rotation" {
  for_each = local.dap_export_external_access

  role       = aws_iam_role.dap_export_secret_rotation[each.key].name
  policy_arn = aws_iam_policy.dap_export_secret_rotation[each.key].arn
}

resource "aws_iam_role_policy_attachment" "dap_export_secret_rotation_vpc_access" {
  for_each = local.dap_export_external_access

  role       = aws_iam_role.dap_export_secret_rotation[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "dap_export_secret_rotation" {
  for_each = local.dap_export_external_access

  function_name    = "dap-export-secret-rotation-${each.key}-${var.environment}"
  filename         = data.archive_file.dap_export_secret_rotation.output_path
  source_code_hash = data.archive_file.dap_export_secret_rotation.output_base64sha256

  role    = aws_iam_role.dap_export_secret_rotation[each.key].arn
  handler = "dap_export_secret_rotation.lambda_handler"
  runtime = "python3.12"
  timeout = 60

  kms_key_arn = aws_kms_key.dap_export_external_secret[each.key].arn

  environment {
    variables = {
      AWS_REGION_NAME   = data.aws_region.current.name
      DAP_EXPORT_BUCKET = module.dap_export_bucket.bucket
      DAP_EXPORT_PREFIX = "latest/"
      IAM_USER_NAME     = aws_iam_user.dap_export_external[each.key].name
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnets[*].id
    security_group_ids = [aws_security_group.dap_export_secret_rotation_lambda[each.key].id]
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_iam_role_policy_attachment.dap_export_secret_rotation,
    aws_iam_role_policy_attachment.dap_export_secret_rotation_vpc_access,
    module.dap_export_secret_rotation_log_group,
  ]
}

resource "aws_lambda_permission" "allow_secretsmanager_dap_export_rotation" {
  for_each = local.dap_export_external_access

  statement_id  = "AllowSecretsManagerRotation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dap_export_secret_rotation[each.key].function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.dap_export_external[each.key].arn
}

resource "aws_secretsmanager_secret_rotation" "dap_export_external" {
  for_each = local.dap_export_external_access

  secret_id           = aws_secretsmanager_secret.dap_export_external[each.key].id
  rotation_lambda_arn = aws_lambda_function.dap_export_secret_rotation[each.key].arn

  rotation_rules {
    automatically_after_days = each.value.rotation_days
  }

  depends_on = [
    aws_lambda_permission.allow_secretsmanager_dap_export_rotation,
    aws_secretsmanager_secret_version.dap_export_external,
  ]
}

resource "aws_s3_bucket_lifecycle_configuration" "dap_export" {
  depends_on = [module.dap_export_bucket]

  bucket = module.dap_export_bucket.bucket

  rule {
    id = "expire-old-versions"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 180
    }

    status = "Enabled"
  }

  rule {
    id = "latest-folder-expiration"

    filter {
      prefix = "latest/"
    }
    expiration {
      days = local.latest_export_files_lifespan_in_days
    }

    status = "Enabled"
  }
}

module "dap_export_job_window" {
  source = "../maintenance_window"

  environment       = var.environment
  prefix            = "marklogic-dap-job"
  schedule          = "cron(00 04 ? * * *)"
  subscribed_emails = var.dap_job_notification_emails
}

resource "aws_ssm_maintenance_window_target" "ml_server" {
  window_id     = module.dap_export_job_window.window_id
  name          = "marklogic-dap-s3-upload-${var.environment}"
  description   = "This should contain the MarkLogic servers from the ${var.environment} environment"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:aws:cloudformation:stack-name"
    values = [local.stack_name]
  }
}

# Non sensitive job output
# tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "dap_upload" {
  name              = "${local.app_log_group_base_name}/dap-upload-task"
  retention_in_days = var.patch_cloudwatch_log_expiration_days
}

resource "aws_ssm_maintenance_window_task" "dap_s3_upload" {
  window_id       = module.dap_export_job_window.window_id
  max_concurrency = 1
  max_errors      = 2 # It should succeed on one of the three hosts where the associated MarkLogic jobs have run
  priority        = 1
  task_arn        = "AWS-RunShellScript"
  task_type       = "RUN_COMMAND"
  cutoff_behavior = "CONTINUE_TASK"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.ml_server.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      comment         = "MarkLogic DAP S3 data upload"
      timeout_seconds = 60

      service_role_arn = module.dap_export_job_window.service_role_arn
      notification_config {
        notification_arn    = module.dap_export_job_window.errors_sns_topic_arn
        notification_events = ["TimedOut", "Cancelled", "Failed"]
        notification_type   = "Command"
      }

      parameter {
        name = "commands"
        values = [
          "set -ex",
          "if [ -z \"$(ls ${local.delta_export_path})\" ]; then echo 'Error ${local.delta_export_path} is empty nothing to export'; exit 1; fi",
          "rm -rf /delta/export-workdir && cp -r ${local.delta_export_path}/. /delta/export-workdir",
          "cd /delta/export-workdir && echo 'Files to upload' && find . -type f",
          "aws s3 cp --region ${data.aws_region.current.name} /delta/export-workdir \"s3://${module.dap_export_bucket.bucket}/latest\" --recursive",
          "aws s3 cp --region ${data.aws_region.current.name} /delta/export-workdir \"s3://${module.dap_export_bucket.bucket}/archive/$(date +%F)\" --recursive",
          "rm -rf ${local.delta_export_path}/*",
        ]
      }

      cloudwatch_config {
        cloudwatch_log_group_name = aws_cloudwatch_log_group.dap_upload.name
        cloudwatch_output_enabled = true
      }
    }
  }
}
