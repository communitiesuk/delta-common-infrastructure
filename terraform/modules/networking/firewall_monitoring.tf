
resource "aws_cloudwatch_dashboard" "network_firewall_dashboard" {
  dashboard_name = "network-firewall-${var.environment}"

  dashboard_body = jsonencode(
    {
      widgets = [
        {
          type = "metric",
          properties = {
            "metrics" : [
              ["AWS/NetworkFirewall", "DroppedPackets", "FirewallName", aws_networkfirewall_firewall.main.name, "AvailabilityZone", aws_subnet.firewall.availability_zone, "Engine", "Stateless", { "color" : "#d62728" }],
              ["AWS/NetworkFirewall", "OtherDroppedPackets", "FirewallName", aws_networkfirewall_firewall.main.name, "AvailabilityZone", aws_subnet.firewall.availability_zone, "Engine", "Stateless", { "color" : "#ff7f0e" }],
              ["AWS/NetworkFirewall", "InvalidDroppedPackets", "FirewallName", aws_networkfirewall_firewall.main.name, "AvailabilityZone", aws_subnet.firewall.availability_zone, "Engine", "Stateless", { "color" : "#ffbb78" }],
              ["AWS/NetworkFirewall", "RejectedPackets", "FirewallName", aws_networkfirewall_firewall.main.name, "AvailabilityZone", aws_subnet.firewall.availability_zone, "Engine", "Stateful", { "color" : "#c5b0d5" }],
              ["AWS/NetworkFirewall", "DroppedPackets", "FirewallName", aws_networkfirewall_firewall.main.name, "AvailabilityZone", aws_subnet.firewall.availability_zone, "Engine", "Stateful", { "color" : "#9467bd" }]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : data.aws_region.current.name,
            "stat" : "Sum",
            "period" : 300,
            "title" : "Dropped Packet count"
            "yAxis" : {
              "left" : {
                "min" : 0,
                "label" : "Packets/5 min"
              }
            }
          }
          height = 6
          width  = 6
          x      = 0
          y      = 0
        },
        {
          type = "metric",
          properties = {
            "metrics" : [
              ["AWS/NetworkFirewall", "Packets", "FirewallName", aws_networkfirewall_firewall.main.name, "CustomAction", "GitHubActionsSSH", "AvailabilityZone", aws_subnet.firewall.availability_zone, "Engine", "Stateless", { "color" : "#000000" }],
              ["AWS/NetworkFirewall", "Packets", "FirewallName", aws_networkfirewall_firewall.main.name, "CustomAction", "DroppedNTP", "AvailabilityZone", aws_subnet.firewall.availability_zone, "Engine", "Stateless", { "color" : "#ff7f0e" }],
              ["AWS/NetworkFirewall", "Packets", "FirewallName", aws_networkfirewall_firewall.main.name, "CustomAction", "ForwardUnmatchedPacket", "AvailabilityZone", aws_subnet.firewall.availability_zone, "Engine", "Stateless", { "color" : "#2ca02c" }]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : data.aws_region.current.name,
            "stat" : "Sum",
            "period" : 300,
            "title" : "Stateless Custom Actions"
          }
          height = 6
          width  = 6
          x      = 6
          y      = 0
        },
        {
          type = "metric",
          properties = {
            "title" : "Dropped packets alarm",
            "annotations" : {
              "alarms" : [aws_cloudwatch_metric_alarm.dropped_packets.arn]
            },
            "liveData" : false,
            "start" : "-PT3H",
            "end" : "PT0H",
            "region" : data.aws_region.current.name,
            "view" : "timeSeries",
            "stacked" : false
          }
          height = 6
          width  = 6
          x      = 12
          y      = 0
        },
        {
          type = "log"
          properties = {
            "query" : "SOURCE 'network-firewall-alert-test' | fields @timestamp, concat(event.src_ip, \":\", event.src_port) as source, concat(event.dest_ip, \":\", event.dest_port) as dest, concat(event.proto, \"[\", event.app_proto, \"]\") as protocol, coalesce(event.tls.sni, event.http.hostname) as host, event.alert.signature as message\n| sort @timestamp desc\n",
            "region" : data.aws_region.current.name,
            "stacked" : false,
            "title" : "Dropped packet logs",
            "view" : "table"
          }
          height = 12
          width  = 18
          x      = 0
          y      = 6
        },
      ]
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "dropped_packets" {
  alarm_name          = "network-firewall-dropped-packets-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "DroppedPackets"
  namespace           = "AWS/NetworkFirewall"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1000"
  alarm_description   = "Network Firewall dropping large number of packets"
  treat_missing_data  = "notBreaching"
  dimensions = {
    FirewallName     = aws_networkfirewall_firewall.main.name
    AvailabilityZone = aws_subnet.firewall.availability_zone
    Engine           = "Stateful"
  }

  # TODO DT-49
  # alarm_actions = sns topic here
  # ok_actions    = sns topic here
}
