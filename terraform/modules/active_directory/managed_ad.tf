resource "aws_directory_service_directory" "directory_service" {
  name                                 = "dluhcdata.local"
  password                             = var.directory_admin_password
  edition                              = var.edition
  type                                 = "MicrosoftAD"
  desired_number_of_domain_controllers = var.number_of_domain_controllers

  vpc_settings {
    vpc_id     = var.vpc.id
    subnet_ids = var.subnets[*].id
  }

  tags = var.default_tags
}
