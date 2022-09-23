resource "aws_security_group" "ad_management_server" {
  name        = "adms-sg"
  description = "Controls access to the management server"
  vpc_id      = var.vpc.id

  ingress {
    description     = "RDP from Bastion"
    from_port       = 3389
    to_port         = 3389
    protocol        = "tcp"
    security_groups = [var.rdp_ingress_sg_id]
  }

  ingress {
    description     = "Ping from Bastion"
    from_port       = 8
    to_port         = 0
    protocol        = "icmp"
    security_groups = [var.rdp_ingress_sg_id]
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
