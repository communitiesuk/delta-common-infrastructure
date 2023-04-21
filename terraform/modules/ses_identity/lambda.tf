#resource "aws_lambda_permission" "allow_cloudwatch" {
#  statement_id  = "AllowExecutionFromCloudWatch"
#  action        = "lambda:InvokeFunction"
#  function_name = aws_lambda_function.test_lambda.function_name
#  principal     = "events.amazonaws.com"
#  source_arn    = "arn:aws:events:eu-west-1:111122223333:rule/RunDaily"
#  qualifier     = aws_lambda_alias.test_alias.name
#}
#
#resource "aws_lambda_alias" "test_alias" {
#  name             = "testalias"
#  description      = "a sample description"
#  function_name    = aws_lambda_function.test_lambda.function_name
#  function_version = "$LATEST"
#}
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
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogSt",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_cloudwatch_log_group" "emails_sent" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 14
}

variable "email_cloudwatch_log_expiration_days" {
  type = number
}

module "sent_emails_log_group" {
  source = "../encrypted_log_groups"
  retention_days = var.email_cloudwatch_log_expiration_days
  log_group_names = [aws_cloudwatch_log_group.emails_sent.name]
  kms_key_alias_name = "sent-emails-log"
}

resource "aws_iam_policy" "cloudwatch_write_policy" {
  name        = "cloudwatch_write_policy"
  path        = "/"
  description = "IAM policy for writing to cloudwatch"
  policy = data.aws_iam_policy_document.cloudwatch_write_policy_document.json
}

resource "aws_sns_topic" "email_deliveries" {
  name = "ses-deliveries-${replace(var.domain, ".", "-")}"
}

resource "aws_sns_topic_subscription" "email_deliveries" {
  topic_arn = aws_sns_topic.email_deliveries.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.test_lambda.arn
}

resource "aws_lambda_permission" "with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.email_deliveries.arn
}

variable "lambda_function_name" {
  default = "lambda_function_name"
}

data "archive_file" "python_lambda_package" {
  type = "zip"
  source_file = "${path.module}/lambdaFunction.py"
  output_path = "lambdaFunction.zip"
}

resource "aws_lambda_function" "test_lambda" {
  function_name = var.lambda_function_name
  environment {
    variables = {
      group_name = aws_cloudwatch_log_group.emails_sent.name,
      event_type = "Bounce",
      log_level = "INFO",
    }
  }
  timeout = 60
  handler = "index.lambda_handler"
  runtime = "python3.8"
  memory_size = 128
  filename = data.archive_file.python_lambda_package.output_path
  source_code_hash = data.archive_file.python_lambda_package.output_base64sha256
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.emails_sent,
  ]
  role = aws_iam_role.iam_for_lambda.arn
}

