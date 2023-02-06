# Terraform

All infrastructure is managed by Terraform.
This repository contains shared infrastructure and application specific infrastructure is defined in the application's repository.

## Tfsec

All terraform code is scanned with [tfsec](https://github.com/aquasecurity/tfsec) to help catch mistakes and deviations from best practice.

## State

Terraform state is stored in an S3 bucket in the same account as the infrastructure.
The state files are encrypted server side using KMS.

The state contains sensitive values, but in order to ensure state compromise would not directly compromise production, we avoid storing production secrets that can be used outside the VPC. We are not as strict for test/staging.

The following are exceptions, sensitive values that can be used outside the VPC:

* SMTP credentials for each of Delta/CPM. The IAM policy for sending emails cannot be restricted to use within the VPC. We could manage these manually instead, but the impact is relatively low.
