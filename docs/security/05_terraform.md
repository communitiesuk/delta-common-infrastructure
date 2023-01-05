# Terraform

All infrastructure is managed by Terraform.
This repository contains shared infrastructure and application specific infrastructure is defined in the application's repository.

## Tfsec

All terraform code is scanned with [tfsec](https://github.com/aquasecurity/tfsec) to help catch mistakes and deviations from best practice.

## State

Terraform state is stored in an S3 bucket in the same account as the infrastructure.
The state files are encrypted server side using KMS.

TODO DT-170: Try and ensure state compromise would not directly compromise production (don't need to be as strict for test/staging)
  So remove AWS access keys/bastion SSH keys for production.
  Document here anything we're not able to remove so we know what to act on if the state is compromised.
