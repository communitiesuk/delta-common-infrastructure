data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  name                   = "shared-emails-${var.environment}"
  attachment_bucket_name = "dluhc-shared-email-attachments-${var.environment}"
}

module "attachment_bucket" {
  source                             = "../s3_bucket"
  bucket_name                        = local.attachment_bucket_name
  access_log_bucket_name             = "${local.attachment_bucket_name}-access-logs"
  access_s3_log_expiration_days      = 30
  noncurrent_version_expiration_days = null
  versioning_enabled                 = false
}

resource "aws_s3_bucket_lifecycle_configuration" "attachments" {
  bucket = module.attachment_bucket.bucket

  rule {
    id     = "expire-staged-attachments"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 1
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_sqs_queue" "dead_letter" {
  name                      = "${local.name}-dead-letter"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "email" {
  name                       = local.name
  message_retention_seconds  = 345600
  visibility_timeout_seconds = 180
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "email" {
  queue_url = aws_sqs_queue.dead_letter.id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.email.arn]
  })
}

resource "aws_sqs_queue_policy" "tls" {
  for_each  = { email = aws_sqs_queue.email, dead_letter = aws_sqs_queue.dead_letter }
  queue_url = each.value.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Deny", Principal = "*", Action = "sqs:*", Resource = each.value.arn
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

resource "aws_iam_role_policy" "publish" {
  name = local.name
  role = var.publisher_role_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "sqs:SendMessage", Resource = aws_sqs_queue.email.arn },
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${module.attachment_bucket.bucket_arn}/notifications/*"
      }
    ]
  })
}

resource "aws_iam_role" "sender" {
  name = local.name
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_kms_key" "logs" {
  description         = "Shared email sender CloudWatch logs"
  enable_key_rotation = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }, Action = "kms:*", Resource = "*" },
      {
        Effect    = "Allow", Principal = { Service = "logs.${data.aws_region.current.name}.amazonaws.com" }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"], Resource = "*"
        Condition = { ArnEquals = { "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.name}" } }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "sender" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}

resource "aws_iam_role_policy" "sender" {
  name = local.name
  role = aws_iam_role.sender.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      { Effect = "Allow", Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"], Resource = aws_sqs_queue.email.arn },
      { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.sender.arn}:*" },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:DeleteObject"]
        Resource = "${module.attachment_bucket.bucket_arn}/notifications/*"
      }
      ], var.backend == "notify" ? [
      { Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = var.notify_api_key_secret_arn }
    ] : [])
  })
}

resource "aws_lambda_function" "sender" {
  function_name                  = local.name
  role                           = aws_iam_role.sender.arn
  filename                       = var.lambda_package
  source_code_hash               = filebase64sha256(var.lambda_package)
  handler                        = "email_sender.lambda_handler.handler"
  runtime                        = "python3.12"
  architectures                  = ["x86_64"]
  timeout                        = 30
  memory_size                    = 256
  reserved_concurrent_executions = 2
  environment {
    variables = {
      EMAIL_BACKEND             = var.backend
      SQS_QUEUE_URL             = aws_sqs_queue.email.url
      NOTIFY_API_KEY_SECRET_ARN = var.notify_api_key_secret_arn
      NOTIFY_TEMPLATE_IDS       = jsonencode(var.notify_template_ids)
      ATTACHMENT_BUCKET         = module.attachment_bucket.bucket
    }
  }
  lifecycle {
    precondition {
      condition     = var.backend != "notify" || (var.notify_api_key_secret_arn != "" && contains(keys(var.notify_template_ids), "delta/large_download_ready"))
      error_message = "Configure the Notify secret ARN and large-download template ID before enabling the sender."
    }
  }
  depends_on = [aws_iam_role_policy.sender]
}

resource "aws_lambda_event_source_mapping" "email" {
  event_source_arn        = aws_sqs_queue.email.arn
  function_name           = aws_lambda_function.sender.arn
  batch_size              = 1
  function_response_types = ["ReportBatchItemFailures"]
  scaling_config { maximum_concurrency = 2 }
}

resource "aws_cloudwatch_metric_alarm" "dead_letter" {
  alarm_name          = "${local.name}-dead-letter"
  alarm_description   = "Email requests require investigation or replay"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.dead_letter.name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarms_sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "backlog" {
  alarm_name          = "${local.name}-backlog"
  alarm_description   = "Oldest email request has waited more than fifteen minutes"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  dimensions          = { QueueName = aws_sqs_queue.email.name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 900
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarms_sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "${local.name}-lambda-errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.sender.function_name }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarms_sns_topic_arn]
}
