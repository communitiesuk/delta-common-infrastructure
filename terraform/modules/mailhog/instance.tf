data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  owners = ["amazon"]
}

# tfsec:ignore:aws-vpc-no-public-egress-sgr
resource "aws_security_group" "main" {
  name        = "mailhog-${var.environment}"
  vpc_id      = var.vpc.id
  description = "Security group for Mailhog instance (test environment only)"

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.ssh_ingress_sg_id]
    description     = "SSH ingress"
  }

  ingress {
    from_port   = 1025
    to_port     = 1025
    protocol    = "tcp"
    cidr_blocks = [var.vpc.cidr_block]
    description = "SMTP"
  }

  ingress {
    from_port   = 8025
    to_port     = 8025
    protocol    = "tcp"
    cidr_blocks = [var.vpc.cidr_block]
    description = "MailHog UI"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all egress"
  }
}

resource "aws_instance" "main" {
  subnet_id                   = var.private_subnet.id
  vpc_security_group_ids      = [aws_security_group.main.id]
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.nano"
  iam_instance_profile        = aws_iam_instance_profile.main.name
  key_name                    = aws_key_pair.main.key_name
  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/user_data.sh", {
    region              = data.aws_region.current.name
    auth_file_secret_id = data.aws_secretsmanager_secret.mailhog_auth_file.id
    smtp_username       = var.ses_user.smtp_username
    smtp_password       = var.ses_user.smtp_password
  })

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }
  root_block_device {
    encrypted = true
  }
  tags = {
    Name = "mailhog-${var.environment}"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "main" {
  key_name   = "mailhog-key-${var.environment}"
  public_key = tls_private_key.main.public_key_openssh
}

resource "aws_route53_record" "private" {
  zone_id = var.private_dns.zone_id
  name    = "mailhog.${var.private_dns.base_domain}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.main.private_ip]
}
