# The auth service ALB used to be shared with another service that no longer exists, so the rules are defined in the
# auth service repository while the listener is defined in this repository for legacy reasons.
resource "aws_lb_listener" "auth" {
  load_balancer_arn = module.auth_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2019-08"
  certificate_arn   = var.certificates["keycloak"].arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Invalid CloudFront key"
      status_code  = "403"
    }
  }
}

output "auth_alb_listener_arn" {
  value = aws_lb_listener.auth.arn
}
