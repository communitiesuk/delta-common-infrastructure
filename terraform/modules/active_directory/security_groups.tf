resource "aws_security_group" "ad_management_server" {
  name        = "adms-sg"
  description = "Controls access to the management server"
  vpc_id      = var.vpc.id

  tags = var.default_tags

  ingress {
    description      = "RDP from Softwire"
    from_port        = 3389
    to_port          = 3389
    protocol         = "tcp"
    cidr_blocks      = ["31.221.86.178/32","167.98.33.82/32","82.163.115.98/32","87.224.105.250/32"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }
}