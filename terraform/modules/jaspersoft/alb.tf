resource "aws_lb_listener" "main" {
  load_balancer_arn = var.public_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2019-08"
  certificate_arn   = var.public_alb.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Invalid CloudFront key"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "vpc_traffic" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    source_ip {
      values = [var.vpc.cidr_block]
    }
  }
}

resource "aws_lb_listener_rule" "check_cloudfront_key" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    http_header {
      http_header_name = "X-Cloudfront-Key"
      values           = [var.public_alb.cloudfront_key]
    }
  }
}

resource "aws_lb_target_group" "main" {
  name_prefix = "jspsft"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc.id

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
