#The auth alb is shared by keycloak and the auth service so we define the listener here and the rules in each repository
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
      message_body = "Unknown route"
      status_code  = "404"
    }
  }
}

output "auth_alb_listener_arn" {
  value = aws_lb_listener.auth.arn
}
