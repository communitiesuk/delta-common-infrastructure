# Optional EC2 Instance Connect Endpoint - allows IAM-authenticated SSH access without
# exposing the bastion to the public internet. See the README for details.

resource "aws_security_group" "instance_connect_endpoint" {
  count = var.enable_instance_connect_endpoint ? 1 : 0

  description = "EC2 Instance Connect Endpoint used to reach the bastion without public internet access"
  name        = "${var.name_prefix}bastion-eice-sg"
  vpc_id      = var.vpc_id

  tags = merge({ "Name" = "${var.name_prefix}bastion-eice-sg" }, var.tags_default, var.tags_sg)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "instance_connect_endpoint_egress" {
  count = var.enable_instance_connect_endpoint ? 1 : 0

  security_group_id        = aws_security_group.instance_connect_endpoint[0].id
  type                     = "egress"
  description              = "Allow the endpoint to reach the bastion over SSH"
  from_port                = var.external_ssh_port
  to_port                  = var.external_ssh_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "ssh_ingress_from_instance_connect" {
  count = var.enable_instance_connect_endpoint ? 1 : 0

  security_group_id        = aws_security_group.bastion.id
  type                     = "ingress"
  description              = "Incoming SSH traffic from the EC2 Instance Connect Endpoint"
  from_port                = var.external_ssh_port
  to_port                  = var.external_ssh_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.instance_connect_endpoint[0].id
}

resource "aws_ec2_instance_connect_endpoint" "bastion" {
  count = var.enable_instance_connect_endpoint ? 1 : 0

  subnet_id          = var.instance_subnet_ids[0]
  security_group_ids = [aws_security_group.instance_connect_endpoint[0].id]
  # Preserving client IP isn't useful here - the instance only needs to trust the endpoint's own security group
  preserve_client_ip = false

  tags = merge({ "Name" = "${var.name_prefix}bastion-eice" }, var.tags_default, var.tags_sg)
}
