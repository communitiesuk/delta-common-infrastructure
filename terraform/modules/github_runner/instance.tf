data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  owners = ["amazon"]
}

# tfsec:ignore:aws-vpc-no-public-egress-sgr
resource "aws_security_group" "main" {
  name        = "github-runner-${var.environment}"
  vpc_id      = var.vpc.id
  description = "Allow SSH access and allow requests out to contact GitHub"

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.ssh_ingress_sg_id]
    description     = "SSH ingress"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all egress"
  }
}

resource "aws_instance" "gh_runner" {
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.main.id]
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.runner.name
  user_data = base64encode(templatefile("${path.module}/scripts/instance_user_data.sh", {
    install_runner = templatefile("${path.module}/scripts/install_runner.sh", {})
    start_runner = templatefile("${path.module}/scripts/start_runner.sh", {
      ssm_parameter_name = aws_ssm_parameter.cloudwatch_agent_config_runner.name
      github_token       = var.github_token
      environment        = var.environment
    })
  }))
  key_name = aws_key_pair.gh_runner.key_name

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }
  root_block_device {
    encrypted = true
  }
  tags = {
    Name = "GitHub-Runner-${var.environment}"
  }
  lifecycle {
    ignore_changes = [user_data, ami]
  }
}

resource "tls_private_key" "gh_runner_ssh" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "gh_runner" {
  key_name   = "gh-runner-key-${var.environment}"
  public_key = tls_private_key.gh_runner_ssh.public_key_openssh
}

resource "aws_route53_record" "gh_runner" {
  zone_id = var.private_dns.zone_id
  name    = "gh-runner.${var.private_dns.base_domain}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.gh_runner.private_ip]
}
