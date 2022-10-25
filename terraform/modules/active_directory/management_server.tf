resource "aws_instance" "ad_management_server" {
  subnet_id              = var.management_server_subnet.id
  ami                    = data.aws_ami.windows_server.id
  instance_type          = var.management_instance_type
  key_name               = aws_key_pair.ad_management_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.ad_management_server.id]
  get_password_data      = true
  iam_instance_profile   = aws_iam_instance_profile.ad_management_profile.name
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }
  root_block_device {
    encrypted = true
  }
  user_data = file("${path.module}/user_data.txt")

  tags = { Name = "ad-management-server-${var.environment}" }
}

resource "aws_ssm_document" "ad_management_server_setup" {
  name          = "ad-management-server-setup-${var.environment}"
  document_type = "Command"
  content = jsonencode(
    {
      "schemaVersion" = "2.2"
      "description"   = "aws:domainJoin"
      "mainSteps" = [
        {
          "action" = "aws:domainJoin",
          "name"   = "domainJoin",
          "inputs" = {
            "directoryId" : aws_directory_service_directory.directory_service.id,
            "directoryName" : aws_directory_service_directory.directory_service.name
            "dnsIpAddresses" : sort(aws_directory_service_directory.directory_service.dns_ip_addresses)
          }
        }
      ]
    }
  )
}

resource "aws_ssm_association" "ad_management_server_setup" {
  name = aws_ssm_document.ad_management_server_setup.name
  targets {
    key    = "InstanceIds"
    values = [aws_instance.ad_management_server.id]
  }
}
