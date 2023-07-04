output "alb" {
  value = {
    arn               = aws_lb.main.arn
    arn_suffix        = aws_lb.main.arn_suffix
    listener_arn      = aws_lb_listener.main.arn
    security_group_id = aws_security_group.alb.id
  }
}
