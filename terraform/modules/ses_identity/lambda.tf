resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.cloudwatch_write_policy.arn
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

data "aws_iam_policy_document" "cloudwatch_write_policy_document" {
  version = "2012-10-17"
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]

    resources = ["arn:aws:logs:${var.region}:${var.account}:log-group:${local.log_group_name_delivered}", "arn:aws:logs:${var.region}:${var.account}:log-group:${local.log_group_name_problem}"]
  }
}

variable "region" {
  type = string
}

variable "account" {
  type = string
}

variable "email_cloudwatch_log_expiration_days" {
  type = number
}

module "sent_emails_log_group" {
  source             = "../encrypted_log_groups"
  retention_days     = var.email_cloudwatch_log_expiration_days
  log_group_names    = [local.log_group_name_problem, local.log_group_name_delivered]
  kms_key_alias_name = "sent-emails-log"
}

locals {
  log_group_name_delivered = "${var.environment}/ses-deliveries-cloudwatch-lambda"
  log_group_name_problem   = "${var.environment}/ses-problems-cloudwatch-lambda"
}

resource "aws_iam_policy" "cloudwatch_write_policy" {
  name        = "cloudwatch_write_policy"
  path        = "/"
  description = "IAM policy for writing to cloudwatch"
  policy      = data.aws_iam_policy_document.cloudwatch_write_policy_document.json
}

resource "aws_sns_topic_subscription" "email_delivery_problems" {
  topic_arn = aws_sns_topic.email_delivery_problems.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.ses_problems_to_cloudwatch_lambda.arn
}

resource "aws_lambda_permission" "with_sns_problems" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ses_problems_to_cloudwatch_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.email_delivery_problems.arn
}

variable "environment" {
  type = string
}

data "archive_file" "python_lambda_package" {
  type        = "zip"
  source_file = "${path.module}/lambdaFunction.py"
  output_path = "lambdaFunction.zip"
}

resource "aws_lambda_function" "ses_problems_to_cloudwatch_lambda" {
  function_name = "${var.environment}-ses-problems-to-cloudwatch"
  tracing_config {
    mode = "Active"
  }
  environment {
    variables = {
      group_name = local.log_group_name_problem,
      event_type = "Bounce,Complaint",
      log_level  = "INFO",
    }
  }
  timeout          = 60
  handler          = "lambdaFunction.lambda_handler"
  runtime          = "python3.8"
  memory_size      = 128
  filename         = data.archive_file.python_lambda_package.output_path
  source_code_hash = data.archive_file.python_lambda_package.output_base64sha256
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
  ]
  role = aws_iam_role.iam_for_lambda.arn
}

resource "aws_lambda_function" "ses_deliveries_to_cloudwatch_lambda" {
  function_name = "${var.environment}-ses-deliveries-to-cloudwatch"
  tracing_config {
    mode = "Active"
  }
  environment {
    variables = {
      group_name = local.log_group_name_delivered,
      event_type = "Delivery",
      log_level  = "INFO",
    }
  }
  timeout          = 60
  handler          = "lambdaFunction.lambda_handler"
  runtime          = "python3.8"
  memory_size      = 128
  filename         = data.archive_file.python_lambda_package.output_path
  source_code_hash = data.archive_file.python_lambda_package.output_base64sha256
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
  ]
  role = aws_iam_role.iam_for_lambda.arn
}
resource "aws_sns_topic_subscription" "email_delivery_success" {
  topic_arn = aws_sns_topic.email_delivery_success.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.ses_deliveries_to_cloudwatch_lambda.arn
}

resource "aws_lambda_permission" "with_sns_delivery" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ses_deliveries_to_cloudwatch_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.email_delivery_success.arn
}
