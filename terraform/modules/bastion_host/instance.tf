# Use the latest Amazon Linux 2 EBS image by default
data "aws_ami" "aws_linux_2" {
  count       = var.custom_ami != "" ? 0 : 1
  most_recent = true
  owners      = ["amazon"]
  name_regex  = "^al2023-ami-2023.*"

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_security_group" "bastion" {
  description = "Enable SSH access to the bastion host from external via SSH port"
  name        = "${var.name_prefix}bastion-sg"
  vpc_id      = var.vpc_id

  tags = merge({ "Name" = "${var.name_prefix}bastion-sg" }, var.tags_default, var.tags_sg)

  lifecycle {
    create_before_destroy = true
  }
}

# Incoming traffic from the internet. Only allow SSH connections
resource "aws_security_group_rule" "ssh_ingress" {
  security_group_id = aws_security_group.bastion.id
  type              = "ingress"
  description       = "Incoming SSH traffic from allowlisted CIDRs"
  from_port         = var.external_ssh_port
  to_port           = var.external_ssh_port
  protocol          = "TCP"
  cidr_blocks       = concat(data.aws_subnet.public_subnets.*.cidr_block, var.external_allowed_cidrs)
}

# Health checks
resource "aws_security_group_rule" "health_check" {
  security_group_id = aws_security_group.bastion.id
  type              = "ingress"
  description       = "Health check"
  from_port         = 2345
  to_port           = 2345
  protocol          = "TCP"
  cidr_blocks       = data.aws_subnet.public_subnets.*.cidr_block
}

# Outgoing traffic - anything VPC only
resource "aws_security_group_rule" "vpc_egress" {
  security_group_id = aws_security_group.bastion.id
  type              = "egress"
  description       = "Egress - VPC only"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [data.aws_vpc.bastion.cidr_block]
}


# Plus allow HTTP(S) internet egress for yum updates
# tfsec:ignore:aws-vpc-no-public-egress-sgr
resource "aws_security_group_rule" "https_egress" {
  security_group_id = aws_security_group.bastion.id
  type              = "egress"
  description       = "Outbound TLS"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

# tfsec:ignore:aws-vpc-no-public-egress-sgr
resource "aws_security_group_rule" "http_egress" {
  security_group_id = aws_security_group.bastion.id
  type              = "egress"
  description       = "Outbound HTTP"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_launch_template" "bastion" {
  name_prefix = "${var.name_prefix}launch-template-"
  image_id    = var.custom_ami != "" ? var.custom_ami : data.aws_ami.aws_linux_2[0].image_id
  # A t3.nano should be perfectly sufficient for a simple bastion host
  instance_type = "t3.nano"
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.bastion.id]
  }
  monitoring {
    enabled = true
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.bastion_host_profile.name
  }
  key_name = var.admin_ssh_key_pair_name

  user_data = base64encode(join("\n", [
    templatefile("${path.module}/init.sh", {
      region                          = var.region
      bucket_name                     = aws_s3_bucket.ssh_keys.bucket
      host_key_secret_id              = aws_secretsmanager_secret_version.bastion_host_key.secret_id
      cloudwatch_config_ssm_parameter = var.log_group_name == null ? "" : aws_ssm_parameter.cloudwatch_agent_config[0].name
    }),
    var.extra_userdata
  ]))

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "bastion" {
  name_prefix = "${var.name_prefix}asg-"
  launch_template {
    id      = aws_launch_template.bastion.id
    version = aws_launch_template.bastion.latest_version
  }
  max_size         = local.instance_count + 1
  min_size         = local.instance_count
  desired_capacity = local.instance_count

  vpc_zone_identifier = var.instance_subnet_ids

  default_cooldown          = 30
  health_check_grace_period = 180
  health_check_type         = "EC2"

  target_group_arns = [
    aws_lb_target_group.bastion_default.arn,
  ]

  termination_policies = [
    "OldestLaunchConfiguration",
  ]

  dynamic "tag" {
    for_each = merge({ "Name" = "${var.name_prefix}bastion-instances-asg" }, var.tags_default, var.tags_asg)
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  instance_refresh {
    strategy = "Rolling"
  }

  lifecycle {
    create_before_destroy = true
  }
}
