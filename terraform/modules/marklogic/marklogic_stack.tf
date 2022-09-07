# Taken from MarkLogic documentation: 
# https://docs.marklogic.com/guide/ec2/CloudFormation

resource "aws_cloudformation_stack" "marklogic" {
  name = "marklogic-stack"

  parameters = {
    IAMRole = aws_iam_instance_profile.ml_instance_profile.name
    KeyName = aws_key_pair.ml_key_pair.name
    NumberOfZones = 3
    NodesPerZone = 1
    #The Availability Zones for VPC subnets. Accept either 1 zone or 3 zones. In the order of Subnet 1, Subnet 2 and Subnet 3 (if applicable).
    AZ = [var.private_subnets[0].availability_zone.name, var.private_subnets[1].availability_zone.name, var.private_subnets[2].availability_zone.name]
    LogSNS = aws_sns_topic.ml_logs.arn
    VPC = var.vpc.id
    PrivateSubnet1 = var.private_subnets[0].id
    PrivateSubnet2 = var.private_subnets[1].id
    PrivateSubnet3 = var.private_subnets[2].id
  }

  template_body = file("${path.module}/cf_template.yml")
}