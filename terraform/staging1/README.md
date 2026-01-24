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
