resource "aws_security_group" "jaspersoft_server" {
  vpc_id      = var.vpc.id
  description = "Jaspersoft server instance"
}

# tfsec:ignore:aws-vpc-no-public-egress-sgr
resource "aws_security_group_rule" "jaspersoft_server_egress" {
  type              = "egress"
  description       = "Allow all egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jaspersoft_server.id
}

resource "aws_security_group_rule" "jaspersoft_server_ssh_ingress" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = var.allow_ssh_from_sg_id
  description              = "SSH from bastion"
  security_group_id        = aws_security_group.jaspersoft_server.id
}

resource "aws_security_group_rule" "jaspersoft_server_http_ingress" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  description       = "HTTP on 8080 from within VPC"
  security_group_id = aws_security_group.jaspersoft_server.id
  cidr_blocks       = [var.vpc.cidr_block]
}

data "aws_region" "current" {}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  owners = ["amazon"]
}

resource "aws_instance" "jaspersoft_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  tags          = { Name = "${var.prefix}jaspersoft-server" }

  subnet_id              = var.private_instance_subnet.id
  vpc_security_group_ids = [aws_security_group.jaspersoft_server.id]
  key_name               = var.ssh_key_name
  iam_instance_profile   = aws_iam_instance_profile.jasperserver.name
  user_data = templatefile(
    "${path.module}/setup_script.sh",
    {
      JASPERSOFT_INSTALL_S3_BUCKET = data.aws_s3_bucket.jaspersoft_binaries.bucket
      JASPERSOFT_CONFIG_S3_BUCKET  = module.config_bucket.bucket
      AWS_REGION                   = data.aws_region.current.name
      DATABASE_PASSWORD_SECRET_ID  = aws_secretsmanager_secret.jaspersoft_db_password.id
    }
  )

  root_block_device {
    encrypted   = true
    volume_size = 40
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  depends_on = [
    aws_db_instance.jaspersoft,
    aws_s3_object.jaspersoft_config_file,
    aws_s3_object.tomcat_systemd_service_file,
    aws_s3_object.jaspersoft_root_index_jsp,
    aws_s3_object.jaspersoft_root_web_xml,
    aws_s3_object.jaspersoft_ldap_config,
    data.aws_s3_object.jaspersoft_install_zip,
  ]

  lifecycle {
    ignore_changes  = [user_data, ami]
    prevent_destroy = true # It should be safe to recreate this server, but take an EBS snapshot first
  }
}

resource "aws_route53_record" "jaspersoft_server" {
  zone_id = var.private_dns.zone_id
  name    = "jaspersoft.${var.private_dns.base_domain}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.jaspersoft_server.private_ip]
}
