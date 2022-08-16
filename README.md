This repository contains Terraform configuration for the infrastructure of "Datamart", containing services such as Delta and the "Common Payments Module".

Infrastructure specific to an application should live in its own codebase, but shared services like AWS SES or 

## Repository contents

* docs - any documentation relevant to Datamart's infrastructure or this repository 
  * adr - Architecture Decision Records
  * diagrams - architecture diagrams
* terraform - all of the Terraform code
  * modules - reusable Terraform config that can be shared between environments
  * test, staging, production - Terraform root modules for each of the three environments
  * backend - configuration for the resources that will store the remote state

## CI/CD

GitHub Actions is the CI/CD platform of choice for minimal maintenance, plus it is used elsewhere in the department.

* A workflow validates all of the terraform config in all pull requests
* When the main branch is updated, a workflow will
  * Run `terraform plan` for the test environment
  * After a reviewer approves the plan, run `terraform apply` for the test environment
  * After that completes successfully, repeat for the next environment (test -> staging -> production)

An possible improvement: skip review/apply step if the plan is "no changes".

The `terraform.yml` workflow could be reused by other Git repositories, but may need to be enhanced with e.g. a continuous deployment option. 
