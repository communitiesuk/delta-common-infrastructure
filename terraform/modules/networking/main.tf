data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  firewall_config = {
    bastion = {
      subnets              = aws_subnet.bastion_private_subnets
      cidr                 = local.bastion_subnet_cidr_10
      http_allowed_domains = ["example.com"]
      tls_allowed_domains  = ["http.cat"]
      sid_offset           = 100
    }
    jaspersoft = {
      subnets              = [aws_subnet.jaspersoft]
      cidr                 = local.jaspersoft_cidr_10
      http_allowed_domains = [".ubuntu.com", ".launchpad.net", ".postgresql.org"]
      tls_allowed_domains  = [".ubuntu.com", ".launchpad.net", "archive.apache.org", ".postgresql.org", "api.snapcraft.io"]
      sid_offset           = 200
    }
    github_runner = {
      subnets              = [aws_subnet.github_runner]
      cidr                 = local.github_runner_cidr_10
      http_allowed_domains = []
      # See https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners#communication-between-self-hosted-runners-and-github
      tls_allowed_domains = [
        "github.com", "api.github.com", "codeload.github.com",
        "objects.githubusercontent.com", "objects-origin.githubusercontent.com", "github-releases.githubusercontent.com", "github-registry-files.githubusercontent.com",
        ".actions.githubusercontent.com",
        "logs.${data.aws_region.current.name}.amazonaws.com", "ec2messages.${data.aws_region.current.name}.amazonaws.com"
      ]
      sid_offset = 300
    }
    ad_dc_private_subnets = {
      subnets              = aws_subnet.ad_dc_private_subnets
      cidr                 = local.ad_dc_subnet_cidr_10
      http_allowed_domains = []
      tls_allowed_domains  = []
      sid_offset           = 400
    }
    ad_other_subnets = {
      subnets              = [aws_subnet.ldaps_ca_server, aws_subnet.ad_management_server]
      cidr                 = local.ad_other_cidr_10
      http_allowed_domains = [".microsoft.com", ".windows.com", ".windowsupdate.com", ".digicert.com"]
      tls_allowed_domains = [
        ".microsoft.com", ".windows.com", ".windowsupdate.com",                                  # Windows update
        "onegetcdn.azureedge.net", "www.powershellgallery.com", "psg-prod-eastus.azureedge.net", # Install PowerShell tools
        "download.mozilla.org", ".mozilla.net",                                                  # Firefox
        ".digicert.com",                                                                         # CRL
        ".eu-west-1.amazonaws.com",                                                              # Test if this can possibly be removed when setting up production in the correct order.
      ]
      sid_offset = 500
    }
    delta_internal_subnets = {
      subnets              = aws_subnet.delta_internal
      cidr                 = local.delta_internal_cidr_10
      http_allowed_domains = []
      tls_allowed_domains  = []
      sid_offset           = 600
    }
    delta_api_subnets = {
      subnets              = [aws_subnet.delta_api]
      cidr                 = local.delta_api_cidr_10
      http_allowed_domains = []
      tls_allowed_domains  = []
      sid_offset           = 700
    }
    cpm_subnets = {
      subnets              = aws_subnet.cpm_private
      cidr                 = local.cpm_private_cidr_10
      http_allowed_domains = []
      tls_allowed_domains  = []
      sid_offset           = 800
    }
    marklogic = {
      subnets              = aws_subnet.ml_private_subnets
      cidr                 = local.ml_subnet_cidr_10
      http_allowed_domains = concat(["repo.ius.io", "mirrors.fedoraproject.org"])
      tls_allowed_domains = concat(local.marklogic_repo_mirror_tls_domains, [
        ".marklogic.com",
        "repo.ius.io", "mirrors.fedoraproject.org",                                      # Yum repos
        "dynamodb.us-east-1.amazonaws.com", "sns.us-east-1.amazonaws.com",               # The instances make some requests to us-east-1 services on startup
        "ec2-instance-connect.eu-west-1.amazonaws.com", "d2lzkl7pfhq30w.cloudfront.net", # Mystery, CF is for yum, but not sure where it comes from

        # Added to silence the noisy firewall alerts. Should check why it's not going via VPC endpoints
        "ec2messages.${data.aws_region.current.name}.amazonaws.com", "ssm.${data.aws_region.current.name}.amazonaws.com"
      ])
      sid_offset = 4000
    }
  }
  firewalled_subnets = flatten([for name, config in local.firewall_config : config.subnets])

  # /etc/yum.repos.d on the MarkLogic hosts references https://mirrors.fedoraproject.org/metalink?repo=epel-7&arch=x86_64
  # This is the list of https enabled mirrors as of 2022-10-26, I ignored the non-HTTPS ones
  # Hardcoding them here obviously isn't a great solution, but I don't think they change quickly and yum will try a few before giving up
  marklogic_repo_mirror_tls_domains = [
    "mirrors.ukfast.co.uk",
    "mirrors.20i.com",
    "fedora.mirrorservice.org",
    "mirror.netcologne.de",
    "eu.edge.kernel.org",
    "mirrors.mivocloud.com",
    "ftp.cc.uoc.gr",
    "fedora.cu.be",
    "mirrors.xtom.de",
    "mirror.efect.ro",
    "mirrors.ptisp.pt",
    "ftp.lysator.liu.se",
    "ftp.fau.de",
    "mirror.netsite.dk",
    "mirror.23m.com",
    "mirror.serverion.com",
    "ftp.acc.umu.se",
    "mirror.init7.net",
    "mirror.karneval.cz",
    "mirror.vpsnet.com",
    "pkg.adfinis.com",
    "centos.anexia.at",
    "mirror.telepoint.bg",
    "mirror.vsys.host",
    "mirror.lanet.network",
    "ftp.upjs.sk",
    "mirror.alwyzon.net",
    "mirrors.nic.cz",
    "mirrors.netix.net",
    "linuxsoft.cern.ch",
    "ftp.plusline.net",
    "mirror.netzwerge.de",
    "mirror.yandex.ru",
    "ge.mirror.cloud9.ge",
    "mirror.dogado.de",
    "www.fedora.is",
    "fr2.rpmfind.net",
    "mirror.niif.hu",
    "mirror.in2p3.fr",
    "mirrors.nxthost.com",
    "epel.mirror.wearetriple.com",
    "epel.srv.magticom.ge",
    "ftp.nsc.ru",
    "ftp.arnes.si",
    "repos.silknet.com",
    "epel.silknet.com",
    "mir01.syntis.net",
    "mirror.im.jku.at",
    "mirror.cspacehostings.com",
    "fastmirror.pp.ua",
    "mirror.wd6.net",
  ]
}

resource "aws_security_group" "aws_service_vpc_endpoints" {
  name        = "vpc-endpoints-${var.environment}"
  description = "VPC Endpoint security group"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Connections from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
}
