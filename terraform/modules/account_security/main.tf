resource "aws_accessanalyzer_analyzer" "eu-west-1" {
  analyzer_name = "eu-west-1-analyzer"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

resource "aws_accessanalyzer_analyzer" "us-east-1" {
  analyzer_name = "us-east-1-analyzer"
  provider      = aws.us-east-1
}

# Only used to alter default security group and ACL to block all traffic
# tfsec:ignore:aws-ec2-require-vpc-flow-logs-for-all-vpcs tfsec:ignore:aws-ec2-no-default-vpc tfsec:ignore:aws-vpc-no-default-vpc
resource "aws_default_vpc" "default" {
  tags = {
    Name = "default-vpc"
  }
}

resource "aws_default_security_group" "default" {
  # Remove all rules from the default security group for the default vpc to make sure traffic is restricted by default
  vpc_id = aws_default_vpc.default.id
  tags = {
    Name = "default-vpc-default-security-group"
  }
}

resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_default_vpc.default.default_network_acl_id
  tags = {
    Name = "vpc-default-acl"
  }
  # no rules defined, deny all traffic in this ACL

  lifecycle {
    ignore_changes = [
      # Ignore changes to subnet_ids, because they are managed by AWS
      subnet_ids,
    ]
  }
}

resource "aws_ebs_encryption_by_default" "default" {
  # enables EBS volume encryption by default
  enabled = true
}
