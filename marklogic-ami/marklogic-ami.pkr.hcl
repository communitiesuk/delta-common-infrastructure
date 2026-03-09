# Packer template to build a MarkLogic AMI with hostname setup that runs before MarkLogic.
# Usage: packer build [-var 'region=eu-west-1'] marklogic-ami.pkr.hcl

packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "ami_name_prefix" {
  type    = string
  default = "marklogic"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ssh_username" {
  type    = string
  default = "ec2-user"
}

# Base AMI to build from. Pass as parameter, e.g. -var 'source_ami_id=ami-xxx'
variable "source_ami_id" {
  type    = string
  default = "ami-01907b01c5d597358"
}

variable "vpc_id" {
  type    = string
  default = "vpc-07a867ec880ffb57e"
}

variable "subnet_id" {
  type    = string
  default = "subnet-0c7ae48d942c6f7b3"
}

variable "iam_instance_profile" {
  type    = string
  default = "PackerSSMBuildRole"
}

source "amazon-ebs" "marklogic" {
  region = var.region
  ami_name = "${var.ami_name_prefix}-{{timestamp}}"
  instance_type = var.instance_type
  ssh_username  = var.ssh_username
  
  ssh_interface        = "session_manager"
  iam_instance_profile = var.iam_instance_profile

  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id
  associate_public_ip_address = false

  ssh_timeout = "15m"

  # Base AMI from source_ami_id variable (default ami-01907b01c5d597358); filter used only if source_ami_id is empty
  ami_description = "MarkLogic with hostname setup (private IP -> hostname before MarkLogic starts)"

  dynamic "source_ami_filter" {
    for_each = var.source_ami_id == "" ? [1] : []
    content {
      filters = {
        name                = "amzn2-ami-hvm-2.0.*-x86_64-gp2"
        root-device-type    = "ebs"
        virtualization-type = "hvm"
      }
      most_recent = true
      owners      = ["amazon"]
    }
  }

  source_ami = var.source_ami_id

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 40
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "${var.ami_name_prefix}-{{timestamp}}"
  }
}

build {
  sources = ["source.amazon-ebs.marklogic"]

  # Create directory first
  provisioner "shell" {
    inline = ["mkdir -p /tmp/marklogic-ami/scripts /tmp/marklogic-ami/systemd /tmp/marklogic-ami/config"]
  }

  # Copy required directories onto the instance so install script can run
  provisioner "file" {
    source      = "scripts/"
    destination = "/tmp/marklogic-ami/scripts"
    direction   = "upload"
  }

  provisioner "file" {
    source      = "systemd/"
    destination = "/tmp/marklogic-ami/systemd"
    direction   = "upload"
  }

  provisioner "file" {
    source      = "config/"
    destination = "/tmp/marklogic-ami/config"
    direction   = "upload"
  }

  # Install hostname setup (script + systemd unit); hostname is set at boot before MarkLogic
  provisioner "shell" {
    inline = [
      "sudo chown -R root:root /tmp/marklogic-ami",
      "cd /tmp/marklogic-ami && sudo bash scripts/install-hostname-setup.sh",
      "rm -rf /tmp/marklogic-ami"
    ]
  }
}
