# Taken from MarkLogic documentation: 
# https://docs.marklogic.com/guide/ec2/CloudFormation

data "aws_secretsmanager_secret_version" "ml_license" {
  secret_id = aws_secretsmanager_secret.ml_license.id
}

resource "aws_secretsmanager_secret" "ml_license" {
  name = "ml-license-${var.environment}"
  tags = var.default_tags
}

resource "aws_cloudformation_stack" "marklogic" {
  name = "marklogic-stack"

  parameters = {
    IAMRole = aws_iam_instance_profile.ml_instance_profile.name
    KeyName = aws_key_pair.ml_key_pair.key_name
    NumberOfZones = 3
    NodesPerZone = 1
    #The Availability Zones for VPC subnets. Accept either 1 zone or 3 zones. In the order of Subnet 1, Subnet 2 and Subnet 3 (if applicable).
    AZ = "${var.private_subnets[0].availability_zone},${var.private_subnets[1].availability_zone},${var.private_subnets[2].availability_zone}"
    LogSNS = aws_sns_topic.ml_logs.arn
    VPC = var.vpc.id
    PrivateSubnet1 = var.private_subnets[0].id
    PrivateSubnet2 = var.private_subnets[1].id
    PrivateSubnet3 = var.private_subnets[2].id

    InstanceType = var.instance_type

    AdminUser = "admin"
    AdminPass = "admin"
    Licensee = jsondecode(data.aws_secretsmanager_secret_version.ml_license.secret_string)["licensee"]
    LicenseKey = jsondecode(data.aws_secretsmanager_secret_version.ml_license.secret_string)["license_key"]
  }

  template_body = file("${path.module}/marklogic_cf_template.yml")
  
  capabilities = ["CAPABILITY_IAM"]
}