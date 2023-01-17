# TODO DT-49
# tfsec:ignore:aws-ec2-require-vpc-flow-logs-for-all-vpcs
resource "aws_vpc" "vpc" {
  cidr_block                           = var.vpc_cidr_block
  enable_dns_hostnames                 = true
  enable_dns_support                   = true
  enable_network_address_usage_metrics = true

  tags = {
    "Name" = "delta-vpc-${var.environment}"
  }
}

resource "aws_default_network_acl" "main" {
  default_network_acl_id = aws_vpc.vpc.default_network_acl_id

  # Allow all intra-VPC traffic
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = aws_vpc.vpc.cidr_block
    from_port  = 0
    to_port    = 0
  }

  # Open ingress for trusted peered VPCs
  dynamic "ingress" {
    for_each = var.open_ingress_cidrs
    content {
      protocol   = "-1"
      rule_no    = ingress.key + 110
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 0
      to_port    = 0
    }
  }

  # Allow HTTPS
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow SSH from allowlisted CIDRs
  dynamic "ingress" {
    for_each = var.ssh_cidr_allowlist
    content {
      protocol   = "tcp"
      rule_no    = ingress.key + 300
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 22
      to_port    = 22
    }
  }

  # Allow Ephemeral ports (TCP)
  ingress {
    protocol   = "tcp"
    rule_no    = 1000
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow Ephemeral ports (UDP)
  ingress {
    protocol   = "udp"
    rule_no    = 1001
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow ICMP ingress
  # Not required by applications, but useful for debugging
  ingress {
    protocol   = "icmp"
    rule_no    = 1002
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
    icmp_code  = -1
    icmp_type  = -1
  }

  # Allow all egress, outbound connections are instead filtered and logged at the Network Firewall
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    "Name" = "vpc-default-acl-${var.environment}"
  }

  lifecycle {
    ignore_changes = [
      subnet_ids
    ]
  }
}

resource "aws_flow_log" "vpc_accepted" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs_accepted.arn
  traffic_type    = "ACCEPT"
  vpc_id          = aws_vpc.vpc.id
}

resource "aws_flow_log" "vpc_rejected" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs_rejected.arn
  traffic_type    = "REJECT"
  vpc_id          = aws_vpc.vpc.id
}

# Flow logs are non-sensitive
# tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "vpc_flow_logs_accepted" {
  name              = "vpc-flow-logs-accepted-${var.environment}"
  retention_in_days = 30
}

# Flow logs are non-sensitive
# tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "vpc_flow_logs_rejected" {
  name              = "vpc-flow-logs-rejected-${var.environment}"
  retention_in_days = 30
}

# https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-cwl.html#flow-logs-iam-role
resource "aws_iam_role" "vpc_flow_logs" {
  name = "vpc-flow-logs-role-${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "vpc-flow-logs-cloudwatch-policy-${var.environment}"
  role = aws_iam_role.vpc_flow_logs.id

  policy = data.aws_iam_policy_document.vpc_flow_logs.json
}

# This does seem slightly excessive, but the AWS documentation insists it "must include at least the following permissions"
# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "vpc_flow_logs" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}
