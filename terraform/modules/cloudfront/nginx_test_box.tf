variable "nginx_test_subnet" {}
variable "vpc" {}

# tfsec:ignore:aws-vpc-no-public-ingress-sgr tfsec:ignore:aws-vpc-no-public-egress-sgr
resource "aws_security_group" "test_nginx_box" {
  vpc_id      = var.vpc.id
  description = "Testing purposes only. Allow HTTP, SSH from Softwire and open egress."

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
}

resource "aws_key_pair" "nginx_test_box_ssh_key" {
  key_name   = "nginx_test_box_ssh_key"
  public_key = file("${path.module}/delta_test.pub")
}

# tfsec:ignore:aws-ec2-enable-at-rest-encryption tfsec:ignore:aws-ec2-enforce-http-token-imds
resource "aws_instance" "nginx_server" {
  ami           = "ami-0e88bd5a70756fd88" #	eu-west-1 focal 20.04 LTS amd64
  instance_type = "t2.micro"
  tags = {
    Name = "nginx_server"
  }

  subnet_id = var.nginx_test_subnet.id

  vpc_security_group_ids = [aws_security_group.test_nginx_box.id]

  key_name = aws_key_pair.nginx_test_box_ssh_key.id

  user_data = <<EOF
#!/bin/bash
sleep 5
apt-get update && apt-get upgrade -y
apt-get -y install nginx
service nginx start
EOF
}

output "nginx_test_box_ip" {
  description = "NGINX test box IP"
  value       = aws_instance.nginx_server.public_ip
}
