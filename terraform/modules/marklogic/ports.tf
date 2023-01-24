locals {
  ml_sg_ingress_port_ranges = [{
    "from_port"   = 22
    "to_port"     = 22
    "description" = "Allow SSH"
    }, {
    "from_port"   = 7997
    "to_port"     = 7998
    "description" = "HTTP to healthchecks/tests"
    }, {
    "from_port"   = 8000
    "to_port"     = 8008
    "description" = "HTTP to admin/default ports"
    }, {
    "from_port"   = 8140
    "to_port"     = 8143
    "description" = "HTTP to CPM ports"
    }, {
    "from_port"   = 8050
    "to_port"     = 8050
    "description" = "HTTP to Delta app port"
    }, {
    "from_port"   = 8053
    "to_port"     = 8053
    "description" = "HTTP to Delta API port"
    }, {
    "from_port"   = 8055
    "to_port"     = 8055
    "description" = "HTTP to Delta store port"
    }, {
    "from_port"   = 8058
    "to_port"     = 8058
    "description" = "HTTP to Delta deploy port"
    }, {
    "from_port"   = 8150
    "to_port"     = 8150
    "description" = "HTTP to Delta XCC port"
    }, {
    "from_port"   = 8060
    "to_port"     = 8062
    "description" = "HTTP to CPM DCLG BI ports"
  }]
  lb_ports = {
    for port in flatten([
      for port_range in local.ml_sg_ingress_port_ranges : range(port_range.from_port, port_range.to_port + 1) if port_range.from_port >= 8000]
    ) :
    tostring(port) => port
  }
}
