resource "aws_security_group" "ml_lb" {
  vpc_id      = var.vpc.id
  description = "MarkLogic LB security group"
  name        = "ml-lb-sg-${var.environment}"

  dynamic "ingress" {
    for_each = local.ml_sg_ingress_port_ranges
    content {
      from_port   = ingress.value["from_port"]
      to_port     = ingress.value["to_port"]
      protocol    = "tcp"
      cidr_blocks = [var.vpc.cidr_block]
      description = ingress.value["description"]
    }
  }

  # tfsec:ignore:aws-vpc-no-public-egress-sgr
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    description = "Allow all egress"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ml_instance" {
  vpc_id      = var.vpc.id
  description = "MarkLogic Instance security group"
  name        = "ml-instance-sg-${var.environment}"

  dynamic "ingress" {
    for_each = local.ml_sg_ingress_port_ranges
    content {
      from_port   = ingress.value["from_port"]
      to_port     = ingress.value["to_port"]
      protocol    = "tcp"
      cidr_blocks = [var.vpc.cidr_block]
      description = ingress.value["description"]
    }
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all traffic within the security group"
  }

  # tfsec:ignore:aws-vpc-no-public-egress-sgr
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    description = "Allow all egress"
    cidr_blocks = ["0.0.0.0/0"]
  }
}