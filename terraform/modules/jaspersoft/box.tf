variable "test_public_subnet" {}

# tfsec:ignore:aws-vpc-no-public-ingress-sgr tfsec:ignore:aws-vpc-no-public-egress-sgr
resource "aws_security_group" "jaspersoft_server" {
  vpc_id      = var.vpc_id
  description = "Testing purposes only. Allow HTTP 80 and 8080, SSH from Softwire and open egress."

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all egress"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["31.221.86.178/32", "167.98.33.82/32", "82.163.115.98/32", "87.224.105.250/32", "87.224.18.46/32"]
    description = "SSH"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["31.221.86.178/32", "167.98.33.82/32", "82.163.115.98/32", "87.224.105.250/32", "87.224.18.46/32"]
    description = "HTTP 8080"
  }
}

resource "aws_instance" "jaspersoft_server" {
  ami           = "ami-00f499a80f4608e1b" #	eu-west-1 bionic 18.04 LTS amd64
  instance_type = "t3.medium"
  tags          = { Name = "${var.prefix}jaspersoft-server" }

  subnet_id                   = var.test_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.jaspersoft_server.id]
  key_name                    = var.ssh_key_name
  iam_instance_profile        = aws_iam_instance_profile.read_jaspersoft_binaries.name
  user_data                   = file("${path.module}/setup_script.sh")
  user_data_replace_on_change = true

  root_block_device {
    encrypted = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  depends_on = [
    aws_s3_object.jaspersoft_config_file,
    aws_s3_object.tomcat_systemd_service_file
  ]
}

output "jaspersoft_box_ip" {
  description = "JasperSoft test box IP"
  value       = aws_eip.jaspersoft_box_ip.public_ip
}

resource "aws_eip" "jaspersoft_box_ip" {
  vpc = true
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.jaspersoft_server.id
  allocation_id = aws_eip.jaspersoft_box_ip.id
}
