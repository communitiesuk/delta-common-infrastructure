resource "aws_networkfirewall_firewall_policy" "main" {
  name = "network-firewall-policy-${var.environment}"

  firewall_policy {
    stateless_default_actions          = ["aws:drop", "DropUnmatchedPacket"]
    stateless_fragment_default_actions = ["aws:drop", "DropUnmatchedFragment"]

    stateless_rule_group_reference {
      priority     = 1
      resource_arn = aws_networkfirewall_rule_group.stateless_main.arn
    }

    stateless_custom_action {
      action_definition {
        publish_metric_action {
          dimension {
            value = "DropUnmatchedPacket"
          }
        }
      }
      action_name = "DropUnmatchedPacket"
    }

    stateless_custom_action {
      action_definition {
        publish_metric_action {
          dimension {
            value = "DropUnmatchedFragment"
          }
        }
      }
      action_name = "DropUnmatchedFragment"
    }

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.stateful_main.arn
    }
  }
}

# tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "firewall_flow" {
  name              = "network-firewall-flow-${var.environment}"
  retention_in_days = 60
}

# tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "firewall_alert" {
  name              = "network-firewall-alert-${var.environment}"
  retention_in_days = 60
}

resource "aws_networkfirewall_logging_configuration" "main" {
  firewall_arn = aws_networkfirewall_firewall.main.arn
  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall_flow.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall_alert.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }
  }
}

resource "aws_networkfirewall_firewall" "main" {
  name                = "network-firewall-${var.environment}"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn
  vpc_id              = aws_vpc.vpc.id
  subnet_mapping {
    subnet_id = aws_subnet.firewall.id
  }
}

locals {
  tcp_protocol_number = 6
}

resource "aws_networkfirewall_rule_group" "stateless_main" {
  lifecycle {
    create_before_destroy = true
  }

  description = "Main stateless rule group for ${var.environment} environment firewall"
  capacity    = 5
  name        = "stateless-rules-${var.environment}"
  type        = "STATELESS"
  rule_group {
    rules_source {
      stateless_rules_and_custom_actions {
        custom_action {
          action_definition {
            publish_metric_action {
              dimension {
                value = "DroppedIntraVPCTraffic"
              }
            }
          }
          action_name = "IntraVPCTrafficMetricAction"
        }

        # Drop intra-VPC traffic, that should never hit the firewall
        stateless_rule {
          priority = 1
          rule_definition {
            actions = ["aws:drop", "IntraVPCTrafficMetricAction"]
            match_attributes {
              source {
                address_definition = aws_vpc.vpc.cidr_block
              }
              destination {
                address_definition = aws_vpc.vpc.cidr_block
              }
            }
          }
        }

        # Send HTTP(S) traffic to the stateful engine to filter
        # Outbound
        stateless_rule {
          priority = 3
          rule_definition {
            actions = ["aws:forward_to_sfe"]
            match_attributes {
              source {
                address_definition = local.all_private_subnets_cidr
              }
              source_port {
                from_port = 1024
                to_port   = 65535
              }
              destination {
                address_definition = "0.0.0.0/0"
              }
              destination_port {
                from_port = 443
                to_port   = 443
              }
              destination_port {
                from_port = 80
                to_port   = 80
              }
              protocols = [local.tcp_protocol_number]
            }
          }
        }

        # Inbound
        stateless_rule {
          priority = 2
          rule_definition {
            actions = ["aws:forward_to_sfe"]
            match_attributes {
              source {
                address_definition = "0.0.0.0/0"
              }
              source_port {
                from_port = 443
                to_port   = 443
              }
              source_port {
                from_port = 80
                to_port   = 80
              }
              destination {
                address_definition = local.all_private_subnets_cidr
              }
              destination_port {
                from_port = 1024
                to_port   = 65535
              }
              protocols = [local.tcp_protocol_number]
            }
          }
        }
      }
    }
  }
}

resource "aws_networkfirewall_rule_group" "stateful_main" {
  description = "Main stateful rule group for ${var.environment} environment firewall"
  capacity    = 100
  name        = "stateful-rules-${var.environment}"
  type        = "STATEFUL"

  rules = templatefile("${path.module}/firewall.rules", {
    BASTION_SUBNETS = local.bastion_subnet_cidr_10
  })
}
