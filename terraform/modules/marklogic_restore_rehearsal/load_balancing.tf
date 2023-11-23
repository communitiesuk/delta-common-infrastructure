resource "aws_lb" "ml_lb" {
  name               = "marklogic-lb-restore-rehearsal"
  load_balancer_type = "network" # The apps use some non-HTTP protocols
  internal           = true
  subnets            = var.private_subnets[*].id
}

resource "aws_lb_target_group" "ml" {
  for_each = local.lb_ports

  name_prefix          = "mm${each.key}"
  port                 = each.value
  protocol             = "TCP"
  vpc_id               = var.vpc.id
  deregistration_delay = 60

  # MarkLogic will sometimes make connections to itself, e.g. Delta ML calling CPM ML
  # 8000, 8001 and 8002 use digest auth which doesn't behave well with this set to false
  preserve_client_ip = each.value == 8000 || each.value == 8001 || each.value == 8002

  health_check {
    interval            = 30 # seconds
    port                = 7997
    unhealthy_threshold = 10
    healthy_threshold   = 10
  }

  lifecycle {
    create_before_destroy = true
  }
}

# We need this so that we can attach a target group to the API's listener, which is HTTP-based
# and cannot target a TCP target group.
resource "aws_lb_target_group" "ml_http" {
  name_prefix          = "mmhttp"
  port                 = 8050
  protocol             = "HTTP"
  vpc_id               = var.vpc.id
  deregistration_delay = 60

  health_check {
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/v1/config/properties"
    interval            = 30 #seconds
    unhealthy_threshold = 10
    healthy_threshold   = 2
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "ml" {
  for_each = local.lb_ports

  load_balancer_arn = aws_lb.ml_lb.arn
  port              = aws_lb_target_group.ml[each.key].port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ml[each.key].arn
  }
}
