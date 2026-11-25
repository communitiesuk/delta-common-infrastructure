locals {
  name           = "azure-dap-export-rotation-reminder-${var.environment}"
  log_group_name = "/aws/lambda/${local.name}"
  log_group_arn  = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group_name}"
}

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "encryption" {
  statement {
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.${data.aws_partition.current.dns_suffix}"]
    }
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = [local.log_group_arn]
    }
  }
}

resource "aws_kms_key" "reminder" {
  description         = "Encrypts ${local.name} Lambda logs"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.encryption.json
}

resource "aws_dynamodb_table" "claims" {
  name         = local.name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "cycle"

  attribute {
    name = "cycle"
    type = "S"
  }
}

resource "aws_cloudwatch_log_group" "reminder" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.reminder.arn
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = local.name
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

data "aws_iam_policy_document" "lambda" {
  statement {
    actions   = ["secretsmanager:DescribeSecret"]
    resources = [var.secret_arn]
  }

  statement {
    actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.claims.arn]
  }

  statement {
    actions   = ["ses:SendEmail"]
    resources = [var.sender.identity_arn]

    condition {
      test     = "StringEquals"
      variable = "ses:FromAddress"
      values   = [var.sender.address]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "ses:Recipients"
      values   = sort(tolist(var.emails))
    }
  }

  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.reminder.arn}:log-stream:*"]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = local.name
  role   = aws_iam_role.lambda.name
  policy = data.aws_iam_policy_document.lambda.json
}

data "archive_file" "reminder" {
  type        = "zip"
  source_file = "${path.module}/reminder.py"
  output_path = "${path.module}/reminder.zip"
}

resource "aws_lambda_function" "reminder" {
  function_name    = local.name
  filename         = data.archive_file.reminder.output_path
  source_code_hash = data.archive_file.reminder.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = "reminder.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30

  environment {
    variables = {
      ENVIRONMENT  = var.environment
      SECRET_ARN   = var.secret_arn
      CLAIMS_TABLE = aws_dynamodb_table.claims.name
      FROM_ADDRESS = var.sender.address
      TO_ADDRESSES = jsonencode(sort(tolist(var.emails)))
    }
  }

  depends_on = [aws_iam_role_policy.lambda]
}

data "aws_iam_policy_document" "scheduler_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${local.name}-scheduler"
  assume_role_policy = data.aws_iam_policy_document.scheduler_trust.json
}

resource "aws_iam_role_policy" "scheduler" {
  name = local.name
  role = aws_iam_role.scheduler.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.reminder.arn
    }]
  })
}

resource "aws_scheduler_schedule" "daily" {
  name                         = local.name
  schedule_expression          = "cron(0 10 * * ? *)"
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.reminder.arn
    role_arn = aws_iam_role.scheduler.arn

    retry_policy {
      maximum_event_age_in_seconds = 3600
      maximum_retry_attempts       = 3
    }
  }

  depends_on = [aws_iam_role_policy.scheduler]
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "${local.name}-errors"
  alarm_description   = "Azure DAP export rotation reminder failed; check the Lambda logs and claim before resending"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarms_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.reminder.function_name
  }
}
