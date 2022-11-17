# TODO: Set up a domain for this and use HTTPS
# tfsec:ignore:aws-elb-http-not-used
resource "aws_lb_listener" "main" {
  load_balancer_arn = var.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_lb_target_group" "main" {
  name_prefix = "jspsft"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/jasperserver/rest_v2/serverInfo"
    unhealthy_threshold = 5
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.jaspersoft_server.id
  port             = 8080
}
