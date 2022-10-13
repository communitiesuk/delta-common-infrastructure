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
You can create an account by uploading your SSH public key to the relevant bucket (your username will be all lowercase), i.e.

```sh
aws s3 cp ~/.ssh/id_rsa.pub s3://$(terraform output -raw bastion_ssh_keys_bucket)/<username>.pub
```

After five minutes you should be able to SSH in to the bastion server. Currently the Softwire London and Cambridge office IPs are allowlisted.

```sh
ssh <username>@$(terraform output -raw bastion_dns_name)
```

Confirm the host key fingerprint matches the terraform output `bastion_host_key_fingerprint`.

## DNS setup

Environments require some manual DNS configuration before the bulk of the resources can be brought up.

When setting up a new environment, make sure the `primary_domain` (e.g. `communities.gov.uk`) and `delegated_domain` (e.g. `internal.communities.gov.uk`) variables are set correctly, the create the DNS module.

```sh
terraform apply -target module.dns
```

Create the delegation and ACM validation records as specified by the `dns_delegation_details` and `dns_acm_validation_record` outputs.
Once that is done you can continue with a full `terraform apply`.

## Authenticating with the AWS CLI

In order to run terraform commands locally you will need to be authenticated to the AWS CLI.
For security we use [aws-vault](https://github.com/99designs/aws-vault) for securely storing credentials locally.

Prerequisites:

1. Install aws-vault as per the [instructions](https://github.com/99designs/aws-vault#installing)
2. Have an account in the mhclg AWS account which has permissions to assume the developer role in the Delta-Dev and
   Delta-Prod accounts
3. Set up MFA on your account in the mhclg account (required for assuming the role in the other accounts)
    1. To do this log in to your account in the web console and navigate to IAM
    2. On the right hand side use the 'Quick links' section to quickly get to the tab 'My security credentials'
    3. Scroll down to the 'Multi-factor authentication' section and work through the wizard to add an MFA
4. Generate and AWS Access Key in the mhclg account
    1. To do this log in to your account in the web console and navigate to IAM
    2. On the right hand side use the 'Quick links' section to quickly get to the tab 'My security credentials'
    3. Scroll down to the 'Access keys' section and select 'Create access key'
    4. Ensure you save your access key somewhere safe - such as in a private folder in Keeper

Setting up AWS Vault:

1. Open your AWS config file in whatever text editor you like
    - This lives at ~/.aws/config, you can do this from bash by running `nano ~/.aws/config`, this will also create the
      file if it doesn't exist yet
2. Add the following contents to the file, filling in your username where needed
    ```
   [profile delta]
   region = eu-west-1
   mfa_serial = arn:aws:iam::448312965134:mfa/<your AWS username>
    
   [profile delta-dev]
   source_profile = delta
   include_profile = delta
   role_arn=arn:aws:iam::486283582667:role/developer
    
   [profile delta-prod]
   source_profile = delta
   include_profile = delta
   role_arn=arn:aws:iam::468442790030:role/developer       
   ```
3. From your terminal run `aws-vault add delta` and enter your Access Key ID and Secret Access Key when prompted
    - Note, when you enter the secret access key you will not be able to see your input
4. If you run `aws-vault list` you should see something like
    ```
   Profile                  Credentials              Sessions                 
   =======                  ===========              ========
   delta                    delta                    -
   delta-dev                -                        -
   delta-prod               -                        -
   ```
5. To use these credentials you use the command `aws-vault exec <profile>` - you will be prompted to enter an MFA code
   for the mhclg account, this is used to create a session which will last a short period of time, during which you
   won't need to enter them again
    1. To run a single command run `aws-vault exec <profile> -- aws <aws command>` (where profile is one of 'delta',
       'delta-dev' and 'delta-prod')
    2. To authenticate your terminal (required for e.g. running terraform commands) run `aws-vault exec <profile>`
