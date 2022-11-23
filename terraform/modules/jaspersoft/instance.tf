resource "aws_security_group" "jaspersoft_server" {
  vpc_id      = var.vpc_id
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
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = var.alb.security_group_id
  description              = "HTTP on 8080 from ALB"
  security_group_id        = aws_security_group.jaspersoft_server.id
}

data "aws_region" "current" {}

data "aws_secretsmanager_secret" "ldap_bind_password" {
  name = "jasperserver-ldap-bind-password-${var.environment}"
}

resource "aws_instance" "jaspersoft_server" {
  ami           = "ami-034943c569985ba6e" #	eu-west-1 bionic 18.04 LTS amd64 ebs-ssd
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
      ENVIRONMENT                  = var.environment
      AWS_REGION                   = data.aws_region.current.name
      LDAP_BIND_PASSWORD_SECRET_ID = data.aws_secretsmanager_secret.ldap_bind_password.id
    }
  )
  user_data_replace_on_change = true

  root_block_device {
    encrypted = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  depends_on = [
    aws_s3_object.jaspersoft_config_file,
    aws_s3_object.tomcat_systemd_service_file,
    aws_s3_object.jaspersoft_root_index_jsp,
    aws_s3_object.jaspersoft_root_web_xml,
    aws_s3_object.jaspersoft_ldap_config,
    data.aws_s3_object.jaspersoft_install_zip,
  ]
}

resource "aws_route53_record" "jaspersoft_server" {
  zone_id = var.private_dns.zone_id
  name    = "jaspersoft.${var.private_dns.base_domain}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.jaspersoft_server.private_ip]
}
