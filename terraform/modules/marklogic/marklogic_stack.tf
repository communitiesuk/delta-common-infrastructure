# Taken from MarkLogic documentation: 
# https://docs.marklogic.com/guide/ec2/CloudFormation

data "aws_secretsmanager_secret_version" "ml_license" {
  secret_id = "ml-license-${var.environment}"
}
data "aws_secretsmanager_secret_version" "ml_admin_user" {
  secret_id = "ml-admin-user-${var.environment}"
}

resource "aws_cloudformation_stack" "marklogic" {
  name = "marklogic-stack-${var.environment}"

  parameters = {
    IAMRole       = aws_iam_instance_profile.ml_instance_profile.name
    KeyName       = aws_key_pair.ml_key_pair.key_name
    NumberOfZones = 3
    NodesPerZone  = 1
    #The Availability Zones for VPC subnets. Accept either 1 zone or 3 zones. In the order of Subnet 1, Subnet 2 and Subnet 3 (if applicable).
    AZ             = "${var.private_subnets[0].availability_zone},${var.private_subnets[1].availability_zone},${var.private_subnets[2].availability_zone}"
    LogSNS         = aws_sns_topic.ml_logs.arn
    VPC            = var.vpc.id
    PrivateSubnet1 = var.private_subnets[0].id
    PrivateSubnet2 = var.private_subnets[1].id
    PrivateSubnet3 = var.private_subnets[2].id

    InstanceType = var.instance_type

    AdminUser  = jsondecode(data.aws_secretsmanager_secret_version.ml_admin_user.secret_string)["username"]
    AdminPass  = jsondecode(data.aws_secretsmanager_secret_version.ml_admin_user.secret_string)["password"]
    Licensee   = jsondecode(data.aws_secretsmanager_secret_version.ml_license.secret_string)["licensee"]
    LicenseKey = jsondecode(data.aws_secretsmanager_secret_version.ml_license.secret_string)["license_key"]
  }

  template_body      = file("${path.module}/marklogic_cf_template.yml")
  timeout_in_minutes = 30
  capabilities       = ["CAPABILITY_IAM"]
  lifecycle {
    # prevent_destroy = true
    ignore_changes = [
      # Otherwise Terraform always detects NoEcho CF parameters as changed
      parameters["AdminPass"],
      parameters["LicenseKey"]
    ]
  }
}