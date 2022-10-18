resource "aws_lb" "ml_lb" {
  name               = "marklogic-lb-${var.environment}"
  load_balancer_type = "network"
  internal           = true
  subnets            = var.private_subnets[*].id
}

resource "aws_lb_target_group" "ml" {
  count = length(local.lb_ports)

  name                 = "ml-target-${var.environment}-${count.index}"
  port                 = local.lb_ports[count.index]
  protocol             = "TCP"
  vpc_id               = var.vpc.id
  deregistration_delay = 60
  preserve_client_ip   = true
  health_check {
    interval            = 10 #seconds
    port                = 7997
    unhealthy_threshold = 5
    healthy_threshold   = 5
  }
}

resource "aws_lb_listener" "ml" {
  count = length(aws_lb_target_group.ml)

  load_balancer_arn = aws_lb.ml_lb.arn
  port              = aws_lb_target_group.ml[count.index].port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ml[count.index].arn
  }
}
