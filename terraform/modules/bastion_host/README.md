# AWS Bastion Host module for Terraform

> This module creates a bastion which manages access by uploading SSH public keys to an S3 bucket.  
> AWS now has tools to manage instance access using AWS credentials instead, either EC2 Instance Connect or AWS Systems Manager Session Manager - consider those alternatives to this module.

## Features

* Optional custom AMI
* Optional multiple instances
* Automatic scaling across multiple subnets
* Route53-based alias DNS record
* User public key management via S3

## User management

* To create a new user, upload their SSH public key to the S3 bucket referenced in the script output. See the README stored there for details.
* To delete a user, remove their key from the S3 bucket.

Any changes to the S3 bucket will be synchronised within 5 minutes

## Input Variables

| Variable | Description | Type | Required | Default |
|----------|-------------|:----:|:--------:|:-------:|
| region | AWS region name | string | yes | |
| public_subnet_ids | List of public subnet ARNs where NLB listeners will be deployed. | list | yes | |
| instance_subnet_ids | List of subnet ARNs where instances will be deployed. | list | yes | |
| vpc_id | ID of the VPC where the bastion will be deployed | string | yes | |
| admin_ssh_key_pair_name | Name of the SSH key pair for the admin user account | string | yes | |
| name_prefix | Prefix to be applied to names of all resources, max 3 characters | string | no | `bst` |
| external_allowed_cidrs | List of CIDRs which can access the bastion | list | no | `["0.0.0.0/0"]` |
| external_ssh_port | Which port to use to SSH into the bastion | number | no | `22` |
| internal_ssh_port | Which port the bastion will use to SSH into other private instances | number | no | `22` |
| instance_count | Number of instances to deploy. Defaults to one per subnet ARN provided. | number | no | `count(var.instance_subnet_ids)` |
| custom_ami | Provide your own AWS AMI to use - useful if you need specific tools on the bastion | string | no | |
| dns_config | Optional details of an alias DNS record for the bastion. [See below](#dns-config) for properties | object | no | |
| tags_default | Tags to apply to all resources | map | no | `{}` |
| tags_lb | Tags to apply to the bastion load balancer | map | no | `{}` |
| tags_asg | Tags to apply to the bastion autoscaling group | map | no | `{}` |
| tags_sg | Tags to apply to the bastion security groups | map | no | `{}` |
| tags_host_key | Tags to apply to the bastion host key secret and KMS key | map | no | `{}` |
| extra_userdata | Extra commands to append to the instance user data script | string | no | |
| log_group_name | The name of a CloudWatch log group to send logs of SSH logins and user/key changes to | string | no | |
| s3_access_log_expiration_days | Days to keep S3 access logs for the keys bucket, defaults to forever | number | no | |

### DNS Config

| Variable | Description | Type | Required | Default |
|----------|-------------|:----:|:--------:|:-------:|
| record_name | Description | DNS alias record name of the bastion host | string | yes | |
| hosted_zone_name | Description | Name of the Route53 hosted zone where to register the record | string | yes | |

## Outputs

| Variable | Description |
|----------|-------------|
| bastion_security_group_id | Security group of the bastion instances |
| bastion_dns_name | DNS name of the bastion. |
| ssh_keys_bucket | Name of the S3 bucket used for user public key storage |
