resource "aws_security_group" "ad_management_server" {
  name        = "adms-sg"
  description = "Controls access to the management server"
  vpc_id      = var.vpc.id

  tags = var.default_tags

  ingress {
    description = "RDP from Softwire"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["31.221.86.178/32", "167.98.33.82/32", "82.163.115.98/32", "87.224.105.250/32"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    # tfsec:ignore:aws-vpc-no-public-egress-sgr
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all egress"
  }
}

resource "aws_security_group_rule" "domain_controllers_to_ca_1" {
  description       = "Directory Services to CA port 135"
  type              = "egress"
  from_port         = 135
  to_port           = 135
  protocol          = "tcp"
  cidr_blocks       = ["${data.aws_instance.ca_server.private_ip}/32"]
  security_group_id = aws_directory_service_directory.directory_service.security_group_id
}

resource "aws_security_group_rule" "domain_controllers_to_ca_2" {
  description       = "Directory Services to CA ports 49152+"
  type              = "egress"
  from_port         = 49152
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["${data.aws_instance.ca_server.private_ip}/32"]
  security_group_id = aws_directory_service_directory.directory_service.security_group_id
}