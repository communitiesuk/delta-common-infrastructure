# Password for an admin user of AD, to be used by CA server, or to manage AD from the management server
resource "random_password" "directory_admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_directory_service_directory" "directory_service" {
  name                                 = "dluhcdata.local"
  password                             = random_password.directory_admin_password.result
  edition                              = var.edition
  type                                 = "MicrosoftAD"
  desired_number_of_domain_controllers = var.number_of_domain_controllers

  vpc_settings {
    vpc_id     = var.vpc.id
    subnet_ids = var.domain_controller_subnets[*].id
  }
}
