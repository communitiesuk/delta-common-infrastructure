resource "aws_sns_topic" "dap_manifest_missing" {
  name = "dap-manifest-missing-${var.environment}"
}

resource "aws_sns_topic_subscription" "dap_manifest_missing_subscription" {
  for_each  = toset(var.dap_manifest_missing_emails)
  topic_arn = aws_sns_topic.dap_manifest_missing.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_iam_role" "dap_manifest_missing_role" {
  name = "dap-manifest-missing-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dap_manifest_missing_basic" {
  role       = aws_iam_role.dap_manifest_missing_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dap_manifest_missing_access" {
  name = "dap-manifest-missing-access-${var.environment}"
  role = aws_iam_role.dap_manifest_missing_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = ["s3:ListBucket"]
        Resource  = "arn:aws:s3:::${var.dap_export_bucket_name}"
        Condition = { StringLike = { "s3:prefix" = ["${var.bucket_manifest_location}*"] } }
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.dap_manifest_missing.arn
      }
    ]
  })
}

data "archive_file" "dap_manifest_missing_checker" {
  type        = "zip"
  source_file = "${path.module}/dap_manifest_checker.py"
  output_path = "${path.module}/dap_manifest_checker.zip"
}

resource "aws_lambda_function" "dap_manifest_missing_checker" {
  function_name    = "dap-manifest-missing-${var.environment}"
  filename         = data.archive_file.dap_manifest_missing_checker.output_path
  source_code_hash = data.archive_file.dap_manifest_missing_checker.output_base64sha256

  role    = aws_iam_role.dap_manifest_missing_role.arn
  handler = "dap_manifest_checker.lambda_handler"
  runtime = "python3.12"
  timeout = 30

  environment {
    variables = {
      BUCKET_NAME   = var.dap_export_bucket_name
      PREFIX        = var.bucket_manifest_location
      SNS_TOPIC_ARN = aws_sns_topic.dap_manifest_missing.arn
      TIMEZONE      = "Europe/London"
    }
  }
}

resource "aws_iam_role" "dap_manifest_missing_scheduler_role" {
  name = "dap-manifest-missing-scheduler-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "dap_manifest_missing_scheduler_invoke" {
  name = "dap-manifest-missing-scheduler-invoke-${var.environment}"
  role = aws_iam_role.dap_manifest_missing_scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = aws_lambda_function.dap_manifest_missing_checker.arn
    }]
  })
}

resource "aws_scheduler_schedule" "dap_manifest_missing_daily" {
  name                         = "dap-manifest-missing-${var.environment}"
  schedule_expression          = "cron(0 7 * * ? *)"
  schedule_expression_timezone = "Europe/London"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.dap_manifest_missing_checker.arn
    role_arn = aws_iam_role.dap_manifest_missing_scheduler_role.arn
  }
}

resource "aws_lambda_permission" "allow_scheduler_invoke_dap_manifest_missing" {
  statement_id  = "AllowExecutionFromScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dap_manifest_missing_checker.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.dap_manifest_missing_daily.arn
}
