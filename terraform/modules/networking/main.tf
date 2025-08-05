data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  firewall_config = {
    bastion = {
      cidr                 = local.bastion_subnet_cidr_10
      http_allowed_domains = []
      tls_allowed_domains  = []
      sid_offset           = 100
    }
    jaspersoft = {
      cidr                 = local.jaspersoft_cidr_10
      http_allowed_domains = []
      tls_allowed_domains = [
        "archive.apache.org", # to download Tomcat
      ]
      sid_offset = 200
    }
    github_runner = {
      cidr                 = local.github_runner_cidr_10
      http_allowed_domains = []
      # See https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners#communication-between-self-hosted-runners-and-github
      tls_allowed_domains = [
        "github.com", "api.github.com",
        "codeload.github.com",
        "objects.githubusercontent.com", "objects-origin.githubusercontent.com", "github-releases.githubusercontent.com", "github-registry-files.githubusercontent.com",
        ".actions.githubusercontent.com",
        "actions-results-receiver-production.githubapp.com",
        "sts.eu-west-1.amazonaws.com", # For getting AWS credentials via OIDC
        # Custom rule for productionresultssa*.blob.core.windows.net in firewall.tf to support the wildcard
        ".amazonlinux.com",
        "index.rubygems.org",
        "rubygems.org",
        "cache.ruby-lang.org"
      ]
      sid_offset = 300
    }
    ad_dc_private_subnets = {
      cidr                 = local.ad_dc_subnet_cidr_10
      http_allowed_domains = []
      tls_allowed_domains  = []
      sid_offset           = 400
    }
    ad_other_subnets = {
      cidr = local.ad_other_cidr_10
      http_allowed_domains = [
        ".microsoft.com", ".windows.com", ".windowsupdate.com", # Windows update
        ".digicert.com", ".o.lencr.org", ".c.lencr.org",        # CRL
        ".firefox.com"                                          # Firefox
      ]
      tls_allowed_domains = [
        # Windows update
        ".microsoft.com", ".windows.com", ".windowsupdate.com",
        # Install PowerShell tools
        ".oneget.org", "onegetcdn.azureedge.net", "www.powershellgallery.com", "cdn.powershellgallery.com", "psg-prod-eastus.azureedge.net",
        # Firefox
        "download.mozilla.org", ".mozilla.net", ".services.mozilla.com", ".mozilla.org",
        # CRL
        ".digicert.com",
        # Allow connections to SSM.
        # These would normally flow through the VPC endpoint, but if Active Directory's DNS forwarding is misconfigured they will instead go to the main region endpoint.
        # The AD Management server relies on SSM to join the domain, so allowing those connections makes it easier to fix.
        "ssm.${data.aws_region.current.name}.amazonaws.com", "ssmmessages.${data.aws_region.current.name}.amazonaws.com", "ec2messages.${data.aws_region.current.name}.amazonaws.com",
        # Does not currently have an endpoint
        "ds.${data.aws_region.current.name}.amazonaws.com"
      ]
      sid_offset = 500
    }
    delta_fo_to_pdf_subnets = {
      cidr                 = local.delta_fo_to_pdf_cidr_10
      http_allowed_domains = []
      tls_allowed_domains  = []
      sid_offset           = 600
    }
    delta_website_subnets = {
      cidr                 = local.delta_website_cidr_10
      http_allowed_domains = []
      tls_allowed_domains = concat(
        [
          "archive.apache.org", # to download Tomcat
          ".clamav.net",        # to download virus definitions for ClamAV
          "download.redis.io",  # to download redis-cli
        ],
        var.attack_iq_testing_domains
      )
      sid_offset = 700
    }
    delta_api_subnets = {
      cidr                 = local.delta_api_cidr_10
      http_allowed_domains = []
      tls_allowed_domains  = []
      sid_offset           = 800
    }
    cpm_subnets = {
      cidr                 = local.cpm_private_cidr_10
      http_allowed_domains = []
      tls_allowed_domains  = []
      sid_offset           = 900
    }
    # Test environment only
    mailhog = var.mailhog_subnet ? {
      subnets              = aws_subnet.mailhog
      cidr                 = local.mailhog_cidr_10
      http_allowed_domains = []
      tls_allowed_domains  = [".github.com", "github.com", "golang.org", "go.googlesource.com", "gopkg.in"] # Downloading and installing golang and MailHog
      sid_offset           = 1100
    } : null
    delta_website_db = {
      subnets              = aws_subnet.delta_website_db
      cidr                 = local.website_db_cidr_10
      http_allowed_domains = []
      tls_allowed_domains  = []
      sid_offset           = 1200
    }
    auth_service = {
      subnets              = aws_subnet.auth_service
      cidr                 = local.auth_service_cidr_10
      http_allowed_domains = []
      tls_allowed_domains = [
        "login.microsoftonline.com", "graph.microsoft.com", # Microsoft domains for OAuth token endpoint and fetching user info
        "xray.${data.aws_region.current.name}.amazonaws.com",
      ]
      sid_offset = 1300
    }
    marklogic = {
      cidr                 = local.ml_subnet_cidr_10
      http_allowed_domains = concat(["repo.ius.io", "mirrors.fedoraproject.org"])
      tls_allowed_domains = concat(
        local.marklogic_repo_mirror_tls_domains,
        [
          ".marklogic.com",
          "repo.ius.io", "mirrors.fedoraproject.org",                        # Yum repos
          "dynamodb.us-east-1.amazonaws.com", "sns.us-east-1.amazonaws.com", # The instances make some requests to us-east-1 services on startup
          "d2lzkl7pfhq30w.cloudfront.net"                                    # Used by MarkLogic's AMI yum updates, unclear why
        ],
        var.attack_iq_testing_domains,
        var.auth_server_domains # Used to fetch access tokens to communicate with Orbeon through the API, those connections are internal
      )
      sid_offset = 4000
    }
    marklogic_rehearsal = {
      cidr                 = local.ml_restore_rehearsal_subnet_cidr_10
      http_allowed_domains = concat(["repo.ius.io", "mirrors.fedoraproject.org"])
      tls_allowed_domains = concat(
        local.marklogic_repo_mirror_tls_domains,
        [
          ".marklogic.com",
          "repo.ius.io", "mirrors.fedoraproject.org",                        # Yum repos
          "dynamodb.us-east-1.amazonaws.com", "sns.us-east-1.amazonaws.com", # The instances make some requests to us-east-1 services on startup
          "d2lzkl7pfhq30w.cloudfront.net"                                    # Used by MarkLogic's AMI yum updates, unclear why
        ],
        var.attack_iq_testing_domains,
        var.auth_server_domains # Used to fetch access tokens to communicate with Orbeon through the API, those connections are internal
      )
      sid_offset = 4100
      // Note that base rules use sid 5000+ 
    }
  }
  firewalled_subnets = concat(
    aws_subnet.bastion_private_subnets,
    aws_subnet.ad_dc_private_subnets,
    aws_subnet.delta_fo_to_pdf,
    aws_subnet.delta_api,
    aws_subnet.delta_website,
    aws_subnet.cpm_private,
    aws_subnet.ml_private_subnets,
    aws_subnet.ml_restore_rehearsal_private_subnets,
    aws_subnet.mailhog,
    aws_subnet.jaspersoft,
    aws_subnet.auth_service,
    [aws_subnet.ldaps_ca_server, aws_subnet.ad_management_server, aws_subnet.github_runner]
  )

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
