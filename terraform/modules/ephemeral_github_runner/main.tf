data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  region     = data.aws_region.current.region
  account_id = data.aws_caller_identity.current.account_id
  name       = "delta-${var.environment}-ephemeral"
  repository = "communitiesuk/delta-marklogic-deploy"
  label      = "${var.environment}-ephemeral"
  network    = var.environment == "production" ? "prod" : var.environment

  parameters = {
    for key in ["app-key-base64", "webhook-secret"] : key => {
      name = "/${local.name}/${key}"
      arn  = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/${local.name}/${key}"
    }
  }
}

data "aws_vpc" "runner" {
  tags = { Name = "delta-vpc-${local.network}" }
}

data "aws_subnet" "runner" {
  vpc_id = data.aws_vpc.runner.id
  tags   = { Name = "github-runner-private-subnet-${local.network}" }

  lifecycle {
    postcondition {
      condition     = !self.map_public_ip_on_launch
      error_message = "The runner subnet must not assign public IPs on launch."
    }
  }
}

resource "aws_security_group" "runner" {
  name        = local.name
  description = "Outbound only for ephemeral ${var.environment} runners"
  vpc_id      = data.aws_vpc.runner.id

  # GitHub and package repository domains are restricted by the runner subnet's network firewall.
  # tfsec:ignore:aws-vpc-no-public-egress-sgr
  egress {
    description = "HTTPS to GitHub, package repositories and AWS service endpoints"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Match the existing runner subnet's outbound SSH path for GitHub deploy-key checkouts.
  # tfsec:ignore:aws-vpc-no-public-egress-sgr
  egress {
    description = "SSH for GitHub deploy-key checkouts"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Private MarkLogic application, admin and test ports"
    protocol    = "tcp"
    from_port   = 7997
    to_port     = 8255
    cidr_blocks = [data.aws_vpc.runner.cidr_block]
  }
}

resource "aws_kms_key" "logs" {
  description         = "CloudWatch logs for ${local.name}"
  enable_key_rotation = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Effect    = "Allow"
        Principal = { Service = "logs.${local.region}.amazonaws.com" }
        Action    = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Resource  = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = [
              "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.name}-*",
              "arn:aws:logs:${local.region}:${local.account_id}:log-group:/github-self-hosted-runners/${local.name}/*",
              "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/apigateway/${local.name}",
            ]
          }
        }
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "webhook" {
  name              = "/aws/apigateway/${local.name}"
  retention_in_days = var.logging_retention_in_days
  kms_key_id        = aws_kms_key.logs.arn
}

module "runners" {
  source  = "github-aws-runners/github-runner/aws"
  version = "8.1.1"

  prefix     = local.name
  aws_region = local.region
  vpc_id     = data.aws_vpc.runner.id
  subnet_ids = [data.aws_subnet.runner.id]
  tags       = { Environment = var.environment }

  github_app = {
    id                 = var.github_app_id
    key_base64_ssm     = local.parameters["app-key-base64"]
    webhook_secret_ssm = local.parameters["webhook-secret"]
  }

  repository_white_list                   = [local.repository]
  enable_organization_runners             = false
  runner_name_prefix                      = "${local.label}-"
  runner_extra_labels                     = [local.label]
  runner_disable_default_labels           = true
  enable_runner_bidirectional_label_match = true
  eventbridge                             = { enable = false }

  enable_ephemeral_runners                = true
  enable_jit_config                       = true
  enable_job_queued_check                 = true
  runners_maximum_count                   = 1
  scale_up_reserved_concurrent_executions = 1
  instance_target_capacity_type           = "on-demand"
  instance_types                          = ["t3.large"]
  runner_boot_time_in_minutes             = 10
  scale_down_idle_confirmation_seconds    = 900
  idle_config                             = []
  job_retry                               = { enable = true, delay_in_seconds = 300, max_attempts = 2 }

  associate_public_ipv4_address        = false
  enable_managed_runner_security_group = false
  runner_additional_security_group_ids = [aws_security_group.runner.id]
  runner_iam_role_managed_policy_arns  = [aws_iam_policy.backup_markers.arn]

  enable_ssm_on_runners     = false
  enable_cloudwatch_agent   = true
  logging_retention_in_days = var.logging_retention_in_days
  logging_kms_key_id        = aws_kms_key.logs.arn

  webhook_lambda_zip                = "${var.artifact_directory}/webhook.zip"
  runners_lambda_zip                = "${var.artifact_directory}/runners.zip"
  runner_binaries_syncer_lambda_zip = "${var.artifact_directory}/runner-binaries-syncer.zip"
  runner_binaries_s3_versioning     = "Enabled"
  webhook_lambda_apigateway_access_log_settings = {
    destination_arn = aws_cloudwatch_log_group.webhook.arn
    format = jsonencode({
      request_id = "$context.requestId"
      route      = "$context.routeKey"
      status     = "$context.status"
    })
  }

  instance_termination_watcher = {
    enable = true
    zip    = "${var.artifact_directory}/termination-watcher.zip"
    features = {
      enable_spot_termination_handler = false
      # This watcher also handles shutdown events for on-demand instances.
      enable_spot_termination_notification_watcher = true
    }
  }
}
