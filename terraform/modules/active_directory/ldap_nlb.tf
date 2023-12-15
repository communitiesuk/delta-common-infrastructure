
resource "aws_lb" "ldap" {
  name               = "ldap-${var.environment}"
  internal           = true
  load_balancer_type = "network"
  subnets            = [for subnet in var.domain_controller_subnets : subnet.id]

  # Network Load balancers are only really sticky if you let them balance cross-zone
  # AWS don't seem to document this, see https://cloudar.be/awsblog/why-aws-nlb-stickiness-is-not-always-sticky/
  enable_cross_zone_load_balancing = true

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "ldap" {
  name_prefix        = "${substr(var.environment, 0, 1)}ldap"
  port               = 389
  protocol           = "TCP"
  target_type        = "ip"
  vpc_id             = var.vpc.id
  preserve_client_ip = true

  stickiness {
    enabled = true
    type    = "source_ip"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "ldaps" {
  name_prefix        = "${substr(var.environment, 0, 1)}ldaps"
  port               = 636
  protocol           = "TCP"
  target_type        = "ip"
  vpc_id             = var.vpc.id
  preserve_client_ip = true

  stickiness {
    enabled = true
    type    = "source_ip"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Certain LDAP updates from Delta only succeed when sent to the "first" domain controller.
# If performance is an issue, we could investigate whether a separate load balancer for read operations would help 
locals {
  split_subnet_a_cidr_block = split(".", var.domain_controller_subnets[0].cidr_block)
  desired_dc_ip_prefix      = "${local.split_subnet_a_cidr_block[0]}.${local.split_subnet_a_cidr_block[1]}.${local.split_subnet_a_cidr_block[2]}."
}

resource "aws_lb_target_group_attachment" "ldap" {
  for_each = {
    for key, val in aws_directory_service_directory.directory_service.dns_ip_addresses :
    key => val if startswith(val, local.desired_dc_ip_prefix)
  }
  target_group_arn = aws_lb_target_group.ldap.arn
  port             = 389
  target_id        = each.value
}

resource "aws_lb_target_group_attachment" "ldaps" {
  for_each = {
    for key, val in aws_directory_service_directory.directory_service.dns_ip_addresses :
    key => val if startswith(val, local.desired_dc_ip_prefix)
  }

  target_group_arn = aws_lb_target_group.ldaps.arn
  port             = 636
  target_id        = each.value
}

resource "aws_lb_listener" "ldap" {
  load_balancer_arn = aws_lb.ldap.arn
  port              = 389
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ldap.arn
  }
}

resource "aws_lb_listener" "ldaps" {
  load_balancer_arn = aws_lb.ldap.arn
  port              = 636
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ldaps.arn
  }
}

resource "aws_route53_record" "ldap_internal_nlb" {
  zone_id = var.private_dns.zone_id
  name    = "ldap.${var.private_dns.base_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.ldap.dns_name
    zone_id                = aws_lb.ldap.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_zone" "active_directory" {
  name    = var.ad_domain
  comment = "vpc-ad-private-hosted-zone-${var.environment}"

  vpc {
    vpc_id = var.vpc.id
  }
}

resource "aws_route53_record" "active_directory_ldap" {
  zone_id = aws_route53_zone.active_directory.zone_id
  name    = var.ad_domain
  type    = "A"

  alias {
    name                   = aws_lb.ldap.dns_name
    zone_id                = aws_lb.ldap.zone_id
    evaluate_target_health = false
  }
}


resource "aws_cloudwatch_metric_alarm" "ldap_lb_healthy_count_low" {
  alarm_name          = "ldap-${var.environment}-lb-healthy-host-count-low"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  evaluation_periods  = 1

  alarm_description  = <<EOF
The Active Directory Domain Controller in use is unhealthy.
This can prevent logins and severely affect Delta + CPM.
We can swap to using the other DC by updating the ${aws_lb_target_group.ldap.name} and ${aws_lb_target_group.ldaps.name} target groups (we do not leave both in the target group long term as it can cause errors updating users).
The Domain Controllers are managed by AWS Directory Service, we have very limited visibility so if this does not resolve itself we will likely need to raise a ticket with AWS support.
  EOF
  alarm_actions      = [var.alarms_sns_topic_arn]
  ok_actions         = [var.alarms_sns_topic_arn]
  treat_missing_data = "breaching"

  metric_query {
    id          = "ldap_or_ldaps_unhealthy_host_count"
    expression  = "SUM(METRICS())"
    label       = "AD target groups unhealthy host count"
    return_data = "true"
  }
  metric_query {
    id = "ldap_tg_unhealthy_host_count"
    metric {
      metric_name = "UnHealthyHostCount"
      namespace   = "AWS/NetworkELB"
      period      = "300"
      stat        = "Maximum"
      dimensions = {
        "TargetGroup" : aws_lb_target_group.ldap.arn_suffix
        "LoadBalancer" : aws_lb.ldap.arn_suffix
      }
    }
  }
  metric_query {
    id = "ldaps_tg_unhealthy_host_count"
    metric {
      metric_name = "UnHealthyHostCount"
      namespace   = "AWS/NetworkELB"
      period      = "300"
      stat        = "Maximum"
      dimensions = {
        "TargetGroup" : aws_lb_target_group.ldaps.arn_suffix
        "LoadBalancer" : aws_lb.ldap.arn_suffix
      }
    }
  }
}
