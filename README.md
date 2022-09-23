This repository contains Terraform configuration for the infrastructure for data collection as a service, which consists of  Delta, the Common Payments Module, and potentially e-claims in the future. 

Infrastructure specific to an individual application should live in its own codebase, but shared resources like AWS SES or the shared VPC will be defined here.

## Repository contents

* docs - any documentation relevant to the shared infrastructure or this repository 
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

The `terraform.yml` workflow could be reused by other Git repositories, but may need to be enhanced with e.g. a continuous deployment option. 

## tfsec

This repository uses [tfsec](https://aquasecurity.github.io/tfsec/) to scan the terraform code for potential security issues.
It can be run using Docker

```sh
docker run --rm -it -v "$(pwd):/src" aquasec/tfsec /src
```

It's also available via Chocolately + other package managers, but the Docker image seems to be more up to date.

Individual rules can be ignored with a comment on the line above with the form `tfsec:ignore:<rule-name>` e.g. `tfsec:ignore:aws-dynamodb-enable-at-rest-encryption`.

## Bastion

There's an SSH bastion server for each environment.
You can create an account by uploading your SSH public key to the relevant bucket, i.e.

```sh
aws s3 cp ~/.ssh/id_rsa.pub s3://$(terraform output -raw bastion_ssh_keys_bucket)/<username>.pub
```

After five minutes you should be able to SSH in to the bastion server. Currently the Softwire London and Cambridge office IPs are allowlisted.

```sh
ssh <username>@$(terraform output -raw bastion_dns_name)
```
