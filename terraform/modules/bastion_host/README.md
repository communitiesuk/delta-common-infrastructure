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

## Connecting via EC2 Instance Connect Endpoint

When `enable_instance_connect_endpoint` is `true`, the bastion can be reached without any public internet
exposure using [EC2 Instance Connect Endpoint](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-with-ec2-instance-connect-endpoint.html)
(EICE). This is the recommended connection method - it requires no static IP and nothing is exposed to the
internet, so `external_allowed_cidrs` can be set to `[]` to close off public SSH access entirely.

Authentication still uses dev's existing SSH keys (uploaded to the S3 bucket as described above); EICE only
provides a private, IAM-authenticated tunnel to the instance in place of a public IP/port.

Add a `Host` block like the following to your `~/.ssh/config` (or edit if you already currently have one configured for the TEST bastion), replacing the port forwards with whichever
ones you need:

```sshconfig
Host delta-test-bastion
    User <youruser>
    ProxyCommand bash -c 'aws ec2-instance-connect open-tunnel --region eu-west-1 --instance-id $(aws ec2 describe-instances --region eu-west-1 --filters "Name=tag:Name,Values=tstbastion-instances-asg" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text)'
    LocalForward 8000 marklogic.vpc.local:8000
    LocalForward 8001 marklogic.vpc.local:8001
    ServerAliveInterval 30
```

Then connect with `ssh delta-test-bastion`.

```bash
aws-vault exec <profile> -- ssh delta-test-bastion
```

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
| enable_instance_connect_endpoint | If true, creates an EC2 Instance Connect Endpoint so the bastion can be reached without public internet access, using IAM-authenticated tunnelling instead of a public CIDR allowlist | bool | no | `false` |
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
| instance_connect_endpoint_id | ID of the EC2 Instance Connect Endpoint, if enabled |
