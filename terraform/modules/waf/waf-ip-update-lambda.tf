data "archive_file" "waf_problematic_ip_update_package" {
  type        = "zip"
  source_file = "${path.module}/waf-problematic-ip-update.py"
  output_path = "waf-problematic-ip-update.zip"
}

variable "log_group_names" {
  type = list(string)
  default = [
      "test-cpm-waf-block-actions-to-lambda",
      "test-delta-website-waf-block-actions-to-lambda",
      "test-auth-waf-block-actions-to-lambda",
      "test-delta-api-waf-block-actions-to-lambda",
    ]
}

data "aws_caller_identity" "current" {}
data "aws_region" "us-east-1" {}

resource "aws_iam_role" "waf_ip_update_lambda_role" {
  provider = aws.us-east-1
  name     = "${var.prefix}cloudfront-waf-ip-update-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

data "aws_iam_policy_document" "lambda_logs_write" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.us-east-1.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
    ]
  }
}

resource "aws_iam_policy" "lambda_logs_write" {
  provider    = aws.us-east-1
  name        = "${var.prefix}cloudfront-waf-ip-update-lambda-cloudwatch-write"
  description = "Allow Lambda to write to its CloudWatch Logs group"
  policy      = data.aws_iam_policy_document.lambda_logs_write.json
}

data "aws_iam_policy_document" "waf_permissions" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = [
      "wafv2:GetIPSet",
      "wafv2:UpdateIPSet",
    ]
    resources = [aws_wafv2_ip_set.blocklist.arn]
  }
}

resource "aws_iam_policy" "waf_permissions" {
  provider    = aws.us-east-1
  name        = "${var.prefix}cloudfront-waf-ip-update-waf-permissions"
  description = "Allow Lambda to read/update the WAF IP set blocklist"
  policy      = data.aws_iam_policy_document.waf_permissions.json
}

resource "aws_iam_role_policy_attachment" "attach_logs" {
  provider    = aws.us-east-1
  role        = aws_iam_role.waf_ip_update_lambda_role.name
  policy_arn  = aws_iam_policy.lambda_logs_write.arn
}

resource "aws_iam_role_policy_attachment" "attach_waf" {
  provider    = aws.us-east-1
  role        = aws_iam_role.waf_ip_update_lambda_role.name
  policy_arn  = aws_iam_policy.waf_permissions.arn
}

resource "aws_lambda_function" "waf_ip_update" {
  provider = aws.us-east-1

  function_name = "${var.prefix}cloudfront-waf-ip-update"
  description   = "Updates the WAF blocklist IP set when matching log entries are seen"
  handler       = "lambdaFunction.lambda_handler"
  runtime       = "python3.12"
  memory_size   = 128
  timeout       = 3
  architectures = ["x86_64"]

  ephemeral_storage {
    size = 512
  }

  filename         = data.archive_file.waf_problematic_ip_update_package.output_path
  source_code_hash = data.archive_file.waf_problematic_ip_update_package.output_base64sha256
  role             = aws_iam_role.waf_ip_update_lambda_role.arn

  environment {
    variables = {
      IPV4_SET_NAME = aws_wafv2_ip_set.blocklist.name
      IPV4_SET_ID   = aws_wafv2_ip_set.blocklist.id
      WAF_SCOPE     = "CLOUDFRONT"
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_iam_role_policy_attachment.attach_logs,
    aws_iam_role_policy_attachment.attach_waf,
  ]
}

resource "aws_lambda_function_event_invoke_config" "waf_ip_update_async" {
  provider = aws.us-east-1

  function_name                 = aws_lambda_function.waf_ip_update.function_name
  maximum_event_age_in_seconds  = 21600
  maximum_retry_attempts        = 2
}

resource "aws_lambda_permission" "allow_logs_invoke" {
  for_each      = toset(var.log_group_names)
  provider      = aws.us-east-1
  statement_id  = "AllowExecutionFromCloudWatchLogs-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.waf_ip_update.function_name
  principal     = "logs.us-east-1.amazonaws.com"
  source_arn    = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:${each.value}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "waf_block_actions" {
  provider        = aws.us-east-1

  name            = "${var.prefix}waf-block-actions-to-lambda"
  log_group_name  = aws_cloudwatch_log_group.main.name
  destination_arn = aws_lambda_function.waf_ip_update.arn

  filter_pattern  = "{ $.action = \"BLOCK\" }"

  depends_on      = [aws_lambda_permission.allow_logs_invoke]
}
