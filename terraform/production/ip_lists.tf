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
        "18.198.196.89/32",  # SAP - CPM middleware production
        "18.193.21.232/32",  # SAP - CPM middleware production
        "3.65.9.91/32",      # SAP - CPM middleware production
        "52.29.190.137/32",  # SAP - CPM middleware production
        "18.197.134.65/32",  # SAP - CPM middleware production
        "3.67.182.154/32",   # SAP - CPM middleware production
        "3.67.255.232/32",   # SAP - CPM middleware production
        "3.66.249.150/32",   # SAP - CPM middleware production
        "3.68.44.236/32",    # SAP - CPM middleware production
      ]
    )
    delta_api = concat(
      local.all_distribution_ip_allowlist,
      [
        "54.76.240.9/32",    # Datamart NAT
        "34.250.225.227/32", # Datamart NAT
        "62.32.120.112/29",  # Home Connections
        "20.68.16.31/32",    # Locata/SectorUK
        "51.11.52.109/32",   # Locata/SectorUK
      ]
    )
    # This is only used if we're IP restricting for testing
    delta_website = concat(
      local.all_distribution_ip_allowlist,
      [
        # DLUHC
        "165.225.196.0/23",
        "165.225.198.0/23",
        "147.161.224.0/23",
        "165.225.16.0/23",
        "147.161.166.0/23",
        "147.161.142.0/23",
        "147.161.144.0/23",
        "147.161.140.0/23",
      ]
    )
    jaspersoft = local.all_distribution_ip_allowlist
  }
}
