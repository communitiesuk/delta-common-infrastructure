locals {
  latest_export_files_lifespan_in_days = 30
  dap_export_external_access = {
    for access in var.dap_export_external_access : access.name => access
  }
  dap_export_rotation_lambda_subnets = var.dap_export_rotation_lambda_subnets == null ? var.private_subnets : var.dap_export_rotation_lambda_subnets
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
  dynamic "statement" {
    for_each = length(var.dap_external_role_arns) > 0 ? [1] : []
    content {
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
  }
  dynamic "statement" {
    for_each = length(var.dap_external_role_arns) > 0 ? [1] : []
    content {
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

  statement {
    sid    = "DenyS151BucketList"
    effect = "Deny"
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      module.dap_export_bucket.bucket_arn,
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        "latest/s151",
        "latest/s151*",
      ]
    }
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

  # tfsec:ignore:aws-vpc-no-public-egress-sgr
  egress {
    description = "Allow HTTPS egress to AWS APIs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

  kms_key_arn                    = aws_kms_key.dap_export_external_secret[each.key].arn
  reserved_concurrent_executions = 1

  environment {
    variables = {
      AWS_REGION_NAME   = data.aws_region.current.name
      DAP_EXPORT_BUCKET = module.dap_export_bucket.bucket
      DAP_EXPORT_PREFIX = "latest/"
      IAM_USER_NAME     = aws_iam_user.dap_export_external[each.key].name
    }
  }

  vpc_config {
    subnet_ids         = local.dap_export_rotation_lambda_subnets[*].id
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

data "archive_file" "dap_export_promoter" {
  type        = "zip"
  source_file = "${path.module}/dap_export_promoter.py"
  output_path = "${path.module}/dap_export_promoter.zip"
}

module "dap_export_promoter_log_group" {
  source = "../encrypted_log_groups"

  retention_days     = var.patch_cloudwatch_log_expiration_days
  kms_key_alias_name = "dap-export-promoter-${var.environment}"
  log_group_names    = ["/aws/lambda/dap-export-promoter-${var.environment}"]
}

resource "aws_sqs_queue" "dap_export_promoter_dead_letter" {
  name                      = "dap-export-promoter-dead-letter-${var.environment}"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_iam_role" "dap_export_promoter" {
  name = "dap-export-promoter-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

data "aws_iam_policy_document" "dap_export_promoter" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = ["${module.dap_export_bucket.bucket_arn}/archive/*"]
  }

  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
    ]
    resources = ["${module.dap_export_bucket.bucket_arn}/latest/*"]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["${module.dap_export_promoter_log_group.log_group_arns[0]}:*"]
  }

  statement {
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
    resources = [module.dap_export_promoter_log_group.kms_key_arn]
  }

  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.dap_export_promoter_dead_letter.arn]
  }

  statement {
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }

  statement {
    actions = [
      "xray:PutTelemetryRecords",
      "xray:PutTraceSegments",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "dap_export_promoter" {
  name        = "dap-export-promoter-${var.environment}"
  description = "Promotes completed DAP archive objects into the latest prefix"
  policy      = data.aws_iam_policy_document.dap_export_promoter.json
}

resource "aws_iam_role_policy_attachment" "dap_export_promoter" {
  role       = aws_iam_role.dap_export_promoter.name
  policy_arn = aws_iam_policy.dap_export_promoter.arn
}

resource "aws_lambda_function" "dap_export_promoter" {
  function_name    = "dap-export-promoter-${var.environment}"
  filename         = data.archive_file.dap_export_promoter.output_path
  source_code_hash = data.archive_file.dap_export_promoter.output_base64sha256

  role        = aws_iam_role.dap_export_promoter.arn
  handler     = "dap_export_promoter.lambda_handler"
  runtime     = "python3.12"
  timeout     = 900
  memory_size = 512

  # Serial processing makes the date/sequencer guard authoritative: an older
  # archive event cannot race a newer event and overwrite its latest object.
  reserved_concurrent_executions = 1

  environment {
    variables = {
      ARCHIVE_PREFIX    = "archive/"
      DAP_EXPORT_BUCKET = module.dap_export_bucket.bucket
      LATEST_PREFIX     = "latest/"
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dap_export_promoter_dead_letter.arn
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_iam_role_policy_attachment.dap_export_promoter,
    module.dap_export_promoter_log_group,
  ]
}

resource "aws_lambda_function_event_invoke_config" "dap_export_promoter" {
  function_name                = aws_lambda_function.dap_export_promoter.function_name
  maximum_event_age_in_seconds = 21600
  maximum_retry_attempts       = 2
}

resource "aws_lambda_permission" "allow_dap_bucket_promoter" {
  statement_id   = "AllowDAPBucketInvocation"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.dap_export_promoter.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = module.dap_export_bucket.bucket_arn
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket_notification" "dap_export_promoter" {
  bucket = module.dap_export_bucket.bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.dap_export_promoter.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "archive/"
  }

  depends_on = [aws_lambda_permission.allow_dap_bucket_promoter]
}

resource "aws_cloudwatch_metric_alarm" "dap_export_promoter_errors" {
  alarm_name          = "dap-export-promoter-errors-${var.environment}"
  alarm_description   = "DAP archive objects are failing promotion into latest"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarms_sns_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.dap_export_promoter.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "dap_export_promoter_dead_letter" {
  alarm_name          = "dap-export-promoter-dead-letter-${var.environment}"
  alarm_description   = "DAP archive objects have exhausted promotion retries"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarms_sns_topic_arn]

  dimensions = {
    QueueName = aws_sqs_queue.dap_export_promoter_dead_letter.name
  }
}

resource "aws_cloudwatch_metric_alarm" "dap_export_promotion_latency" {
  alarm_name          = "dap-export-promotion-latency-${var.environment}"
  alarm_description   = "DAP archive objects are taking over five minutes to appear in latest"
  namespace           = "Delta/DAPExport"
  metric_name         = "PromotionLatencySeconds"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 300
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarms_sns_topic_arn]
}
