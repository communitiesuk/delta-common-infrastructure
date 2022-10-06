resource "aws_networkfirewall_firewall_policy" "main" {
  name = "network-firewall-policy-${var.environment}"

  firewall_policy {
    stateless_default_actions          = ["aws:pass"]
    stateless_fragment_default_actions = ["aws:pass"]
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
