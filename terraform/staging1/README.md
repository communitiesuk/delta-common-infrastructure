# Staging1 Environment - MarkLogic Cluster Only

This environment contains a MarkLogic cluster that shares the VPC and networking infrastructure with the staging environment.

## Overview

The staging1 cluster is deployed in the same VPC as staging but uses separate resources:
- **DNS**: `marklogic1.vpc.local` (staging uses `marklogic.vpc.local`)
- **Load Balancer**: Separate NLB for staging1
- **Security Groups**: Separate security groups
- **IAM Roles**: Separate roles and policies
- **S3 Buckets**: Separate backup and configuration buckets

## Setup Instructions

### Prerequisites

Before running `terraform apply`, ensure you have:

1. **AWS Profile configured**: `export AWS_PROFILE=delta-dev`
2. **MarkLogic Admin Secret**: The secret `ml-admin-user-staging1` must exist in AWS Secrets Manager

### Step 1: Create and Tag the MarkLogic Admin Secret

The secret `ml-admin-user-staging1` must exist in AWS Secrets Manager with the following tag:
- Key: `delta-marklogic-deploy-read`
- Value: `staging1`

**If the secret doesn't exist**, create it:
```bash
export AWS_PROFILE=delta-dev

aws secretsmanager create-secret \
  --name ml-admin-user-staging1 \
  --secret-string '{"username":"admin","password":"YOUR_PASSWORD"}' \
  --tags Key=delta-marklogic-deploy-read,Value=staging1
```

**If the secret exists but is missing the tag**, add it:
```bash
export AWS_PROFILE=delta-dev

aws secretsmanager tag-resource \
  --secret-id ml-admin-user-staging1 \
  --tags Key=delta-marklogic-deploy-read,Value=staging1
```

### Step 2: Run Terraform

After ensuring the secret is properly tagged, run:

```bash
cd terraform/staging1
export AWS_PROFILE=delta-dev
terraform init
terraform plan  # Verify the plan looks correct
terraform apply
```

## DNS Configuration

The staging1 cluster uses a separate DNS name `marklogic1.vpc.local` to avoid conflicts with staging's `marklogic.vpc.local`. 

The Route53 record for `marklogic1.vpc.local` is created automatically by Terraform in `staging1/main.tf`. 

**Note:** The staging1 cluster will be accessible at `marklogic1.vpc.local`, while staging remains at `marklogic.vpc.local`.

## Resources Created

- MarkLogic CloudFormation stack (`marklogic-stack-staging1-staging1`)
- MarkLogic Network Load Balancer
- MarkLogic security groups
- MarkLogic IAM roles and policies
- MarkLogic backup and configuration S3 buckets
- MarkLogic monitoring and alarms
- Maintenance windows for patching
- Route53 record: `marklogic1.vpc.local`

## Resources Shared with Staging

- VPC and subnets (referenced via data sources)
- Private DNS zone (`vpc.local`)
- Session Manager config (referenced via data sources)
- ECR pull-through cache rule (account-level, managed by staging)

## Access

The MarkLogic cluster is accessible at:
- **Internal DNS**: `marklogic1.vpc.local`
- **Load Balancer DNS**: Available via `terraform output ml_lb_dns_name`


# Destroying the Staging1 Environment

## Overview

The staging1 environment can be removed manually using Terraform. This will delete all resources created for the staging1 MarkLogic cluster.

The approach is to use the `terraform destroy` command in the `terraform/staging1` directory. However, there are certain protections in place to stop the deletion of some of these resources, and so these will need to be temporarily removed before the destroy can be run.

The destroy also wont fully work whilst any staging1 S3 buckets contain objects or the backup vault contains recovery points. These will need to be removed before the destroy can be run.

**Note: Ensure any required resources are backed up or no longer needed before proceeding.**


### Step 1 - Dry Run

In `terraform/staging1`, run the following command to see what resources will be destroyed:

```bash
terraform plan -destroy
```
Ensure the output of the plan only targets resources in staging1 and does not include any resources from other environments.

### Step 2 - Empty S3 Buckets

Terraform can't delete these buckets while old versions/delete markers remain, so these will need to be removed before the destroy can be run. 

The quickest way to do this in the AWS Console is to go to the S3 service, find the buckets created for staging1, and empty them.


### Step 3 - Clear AWS Backup Recovery Points

The vault can't be deleted while it holds recovery points so these will need to be removed before the destroy can be run. 

To get a list of recovery points, run the following command:

```bash
aws backup list-recovery-points-by-backup-vault \               
  --backup-vault-name marklogic-backup-vault-staging1 \
  --query 'RecoveryPoints[].{ARN:RecoveryPointArn, Resource:ResourceArn, Created:CreationDate, Status:Status, SizeBytes:BackupSizeInBytes}' \
  --output table
```

**Note: Ensure any required resources are backed up or no longer needed before proceeding.**

To delete these recovery points, run the following command:

```bash
for ARN in $(aws backup list-recovery-points-by-backup-vault --backup-vault-name marklogic-backup-vault-staging1 --query 'RecoveryPoints[].RecoveryPointArn' --output text); do
  echo "Deleting: $ARN"
  aws backup delete-recovery-point --backup-vault-name marklogic-backup-vault-staging1 --recovery-point-arn "$ARN"
done
```

### Step 4 - Remove Resource Protections

Two resource types in this codebase are deliberately protected from deletion:

| File | Resource | Protects |
|---|---|---|
| `modules/encrypted_log_groups/main.tf` | `aws_cloudwatch_log_group` | CloudWatch log groups |
| `modules/marklogic/ebs.tf` | `aws_ebs_volume.marklogic_data_volumes` | MarkLogic database data|

These protections will need to be manually removed to allow Terraform to destroy the resources.

To remove these protections, run the following commands in the `terraform` directory:

```bash
sed -i '' 's/prevent_destroy = true/prevent_destroy = false/g' modules/encrypted_log_groups/main.tf
sed -i '' 's/prevent_destroy = true/prevent_destroy = false/g' modules/marklogic/ebs.tf

```

**Note: Ensure these protections are re-enabled after the destroy is complete and not committed with any changes.**

### Step 5 - Review and run the destroy

Run the following commands to see a final plan of the destroy and consider uploading to the ticket you are working on or checking with other devs if you are unsure about any of the resources that will be destroyed:

```bash
terraform plan -destroy -out=destroy.plan
terraform show -no-color destroy.plan > destroy-plan.txt
```

Once you are happy with the plan, run the destroy:

```bash
terraform destroy
```

or to use the plan file:

```bash
terraform apply destroy.plan
```

The teardown will take some time to complete. Once complete, run the following command to confirm the resources have been removed:

```bash
terraform state list
``` 

You can also manually check the AWS console to confirm the resources have been removed.


### Step 6 - Remove terraform files

The steps above will remove the resources created by Terraform, but the files themselves will remain in the repository and will need to be removed manually to prevent recreation of the staging1 environment on the next terraform apply.

To do this delete any terraform files in the `terraform/staging1` folder and create a PR to commit the changes.

**Note: Ensure you have reverted the resource protection changes and removed any files created by running the above commands before committing/merging.**
