# Taken from MarkLogic documentation: 
# https://docs.marklogic.com/guide/ec2/CloudFormation

data "aws_secretsmanager_secret_version" "ml_license" {
  secret_id = "ml-license-${var.environment}"
}

data "aws_secretsmanager_secret_version" "ml_admin_user" {
  secret_id = "ml-admin-user-${var.environment}"
}

locals {
  stack_name = "marklogic-stack-restore-rehearsal"
  amis = {
    # https://aws.amazon.com/marketplace/server/configuration?productId=52ce1567-c738-4208-be90-08b575f2c41d
    "10.0-9.5"  = "ami-07701d367691e0220"
    "10.0-10.2" = "ami-072f9d963cd827efb"
  }
}

resource "aws_cloudformation_stack" "marklogic" {
  name = local.stack_name

  parameters = {
    IAMRole       = aws_iam_instance_profile.ml_instance_profile.name
    KeyName       = aws_key_pair.ml_key_pair.key_name
    NumberOfZones = 3
    NodesPerZone  = 1 # Changing this will require modifying the template, as multiple nodes cannot have the same EBS volume attached
    # The Availability Zones for VPC subnets. Accept either 1 zone or 3 zones. In the order of Subnet 1, Subnet 2 and Subnet 3 (if applicable).
    AZ             = "${var.private_subnets[0].availability_zone},${var.private_subnets[1].availability_zone},${var.private_subnets[2].availability_zone}"
    VPC            = var.vpc.id
    PrivateSubnet1 = var.private_subnets[0].id
    PrivateSubnet2 = var.private_subnets[1].id
    PrivateSubnet3 = var.private_subnets[2].id
    AMI            = local.amis[var.marklogic_ami_version]

    DataVolume1 = aws_ebs_volume.marklogic_data_volumes[var.private_subnets[0].tags.Name].id
    DataVolume2 = aws_ebs_volume.marklogic_data_volumes[var.private_subnets[1].tags.Name].id
    DataVolume3 = aws_ebs_volume.marklogic_data_volumes[var.private_subnets[2].tags.Name].id
    VolumeSize  = var.data_volume.size_gb
    VolumeType  = local.ebs_volume_type

    TargetGroupARNs       = join(",", concat([for tg in aws_lb_target_group.ml : tg.arn], [aws_lb_target_group.ml_http.arn]))
    InstanceSecurityGroup = aws_security_group.ml_instance.id

    InstanceType = var.instance_type

    AdminUser  = jsondecode(data.aws_secretsmanager_secret_version.ml_admin_user.secret_string)["username"]
    AdminPass  = jsondecode(data.aws_secretsmanager_secret_version.ml_admin_user.secret_string)["password"]
    Licensee   = jsondecode(data.aws_secretsmanager_secret_version.ml_license.secret_string)["licensee"]
    LicenseKey = jsondecode(data.aws_secretsmanager_secret_version.ml_license.secret_string)["license_key"]
  }

  template_body      = file("${path.module}/../marklogic/marklogic_cf_template.yml")
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
  depends_on = [aws_iam_role_policy_attachment.ml_attach]
}
