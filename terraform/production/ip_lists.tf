locals {
  all_distribution_ip_allowlist = concat(
    var.allowed_ssh_cidrs,
    ["${module.networking.nat_gateway_ip}/32"]
  )
  cloudfront_ip_allowlists = {
    cpm = concat(
      local.all_distribution_ip_allowlist,
      [
        "165.225.81.30/32",  # Hemel Outbound
        "18.169.126.200/32", # New AWS SAP Connection - once SAP is fully on AWS, we can remove other SAP addresses 
        "195.99.1.2/32",     # Not labelled by Digital Space - assuming current SAP
        "213.86.38.254/32",  # Not labelled by Digital Space - assuming current SAP
        "34.250.255.227/32", # Datamart NAT
        "54.76.240.9/32",    # Datamart NAT
        "62.60.23.206/32",   # DLUHC Outbound
        "86.16.25.15/32",    # DLUHC Outbound
        "62.60.23.222/32",   # DLUHC Outbound
        "35.176.187.166/32", # DLUHC ITMP Prod
        "52.56.253.115/32",  # DLUHC ITMP Test
      ]
    )
    delta_api = concat(
      local.all_distribution_ip_allowlist,
      [
        "54.76.240.9/32",    # Datamart NAT
        "34.250.225.227/32", # Datamart NAT
        "62.32.120.112/29",  # Home Connections
      ]
    )
    delta_website = local.all_distribution_ip_allowlist
    jaspersoft    = local.all_distribution_ip_allowlist
  }
}
