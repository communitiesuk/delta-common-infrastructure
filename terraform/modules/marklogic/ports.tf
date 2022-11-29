locals {
  lb_ports = [8000, 8001, 8002, 8003, 8004, 8005, 8006, 8007, 8008, 8140, 8141, 8142, 8050, 8055, 8058, 8150]
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
    "to_port"     = 8010
    "description" = "HTTP to admin/default ports"
    }, {
    "from_port"   = 8140
    "to_port"     = 8142
    "description" = "HTTP to CPM ports"
    }, {
    "from_port"   = 8050
    "to_port"     = 8050
    "description" = "HTTP to Delta app-port"
    }, {
    "from_port"   = 8055
    "to_port"     = 8055
    "description" = "HTTP to Delta store port"
    }, {
    "from_port"   = 8058
    "to_port"     = 8058
    "description" = "HTTP to Delta delta-app-port"
    }, {
    "from_port"   = 8150
    "to_port"     = 8150
    "description" = "HTTP to Delta XCC port"
  }]
}
