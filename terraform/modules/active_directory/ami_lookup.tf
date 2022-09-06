data "aws_ami" "windows_server" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }

  owners = ["amazon"]
}