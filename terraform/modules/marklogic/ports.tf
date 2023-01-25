locals {
  ml_sg_ingress_port_ranges = [{
    "from_port"   = 22
    "to_port"     = 22
    "description" = "Allow SSH"
    "log_name"    = "not-logged"
    }, {
    "from_port"         = 7997
    "to_port"           = 7997
    "description"       = "HTTP to healthchecks/tests"
    "log_name_fragment" = "healthcheck"
    }, {
    "from_port"         = 8000
    "to_port"           = 8002
    "description"       = "HTTP to admin/default ports"
    "log_name_fragment" = "admin-default"
    }, {
    "from_port"         = 8050
    "to_port"           = 8050
    "description"       = "HTTP to Delta app port"
    "log_name_fragment" = "app"
    }, {
    "from_port"         = 8053
    "to_port"           = 8053
    "description"       = "HTTP to Delta API port"
    "log_name_fragment" = "api"
    }, {
    "from_port"         = 8055
    "to_port"           = 8055
    "description"       = "HTTP to Delta store port"
    "log_name_fragment" = "store"
    }, {
    "from_port"         = 8058
    "to_port"           = 8058
    "description"       = "HTTP to Delta deploy port"
    "log_name_fragment" = "deploy"
    }, {
    "from_port"         = 8060
    "to_port"           = 8062
    "description"       = "HTTP to CPM DCLG BI ports"
    "log_name_fragment" = "cpm-dclg-bi"
    }, {
    "from_port"         = 8140
    "to_port"           = 8143
    "description"       = "HTTP to CPM ports"
    "log_name_fragment" = "cpm"
    }, {
    "from_port"         = 8150
    "to_port"           = 8150
    "description"       = "HTTP to Delta XCC port"
    "log_name_fragment" = "xcc"
  }]
  lb_ports = {
    for port in flatten([
      for port_range in local.ml_sg_ingress_port_ranges : range(port_range.from_port, port_range.to_port + 1) if port_range.from_port >= 8000]
    ) :
    tostring(port) => port
  }
  log_port_details = flatten([for port_range_details in local.ml_sg_ingress_port_ranges :
    [for port in range(port_range_details.from_port, port_range_details.to_port + 1) : {
      port : port,
      log_name_fragment : port_range_details.log_name_fragment
      }
    ]
    if port_range_details.from_port >= 7997
  ])
}
