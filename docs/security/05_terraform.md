# Terraform

All infrastructure is managed by Terraform.
This repository contains shared infrastructure and application specific infrastructure is defined in the application's repository.

## Tfsec

All terraform code is scanned with [tfsec](https://github.com/aquasecurity/tfsec) to help catch mistakes and deviations from best practice.

## State

Terraform state is stored in an S3 bucket in the same account as the infrastructure.

TODO: Use KMS to encrypt terraform state bucket

TODO: Try and ensure state compromise would not directly compromise the environment
  So remove bastion SSH key, AWS access keys.
