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
docker run --pull=always --rm -it -v "$(pwd):/src" aquasec/tfsec /src
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
    * This lives at ~/.aws/config, you can do this from bash by running `nano ~/.aws/config`, this will also create the
      file if it doesn't exist yet
2. Add the following contents to the file, filling in your username where needed

   ```text
   [profile mhclg]
   region = eu-west-1
   mfa_serial = arn:aws:iam::448312965134:mfa/<your AWS username>

   [profile delta-dev]
   source_profile = mhclg
   include_profile = mhclg
   role_arn=arn:aws:iam::486283582667:role/developer

   [profile delta-prod]
   source_profile = mhclg
   include_profile = mhclg
   role_arn=arn:aws:iam::468442790030:role/developer
   ```

3. From your terminal run `aws-vault add mhclg` and enter your Access Key ID and Secret Access Key when prompted
    * Note, when you enter the secret access key you will not be able to see your input
4. If you run `aws-vault list` you should see something like

   ```text
   Profile                  Credentials              Sessions
   =======                  ===========              ========
   mhclg                    mhclg                    -
   delta-dev                -                        -
   delta-prod               -                        -
   ```

5. To use these credentials you use the command `aws-vault exec <profile>` - you will be prompted to enter an MFA code
   for the mhclg account, this is used to create a session which will last a short period of time, during which you
   won't need to enter them again
    1. To run a single command run `aws-vault exec <profile> -- aws <aws command>` (where profile is one of 'mhclg',
       'delta-dev' and 'delta-prod')
    2. To authenticate your terminal (required for e.g. running terraform commands) run `aws-vault exec <profile>`

## Creating an environment

### 1 DNS setup

The terraform supports multiple domains, though one of these will have to be chosen as the primary domain
which will get passed to the applications to use for links, emails etc.

The CloudFront distributions require valid certificates before we can configure them properly.
If we control the DNS zone that's not an issue, we can just create those modules first, but if we are using records managed by DLUHC
then we will either need to stop after creating the CloudFront distributions and wait for the records to be created,
or use a secondary domain we do control in the meantime.

Add an ssl_certificates module for each set of certs you want to have available and create them,
along with an SES identity if the environment will have one.

```sh
terraform apply -target module.ssl_certs -target module.ses_identity
```

For domains we control create the DNS records to validate the certificates with a dns_records module and apply it now.
For other domains, request that the records from the `required_dns_records` output are created and continue.

### 2 Network + Bastion

Bring up the VPC and the SSH bastion. Other components implicitly depend on the VPC endpoints, firewall, NAT Gateway etc.

```sh
terraform apply -target module.networking
terraform apply -target module.bastion
```

### 3 Active Directory

MarkLogic can't be configured without AD, so bring this up next.

```sh
terraform apply -target module.active_directory
```

Complete the manual "First time setup" steps in the module README.
Create the required containers, service users, and optionally test users, using the scripts in `manual_scripts/active_directory`, changing and noting the passwords.

### 4 MarkLogic

Follow the instructions in the module README to set up the required secrets then bring the MarkLogic cluster up.

```sh
terraform apply -target module.marklogic
```

### 5 MarkLogic configuration - GitHub Runner

Follow the instructions in the GitHub Runner module README to get the runner creation token, bring the module up.

```sh
terraform apply -target module.gh_runner -var="github_actions_runner_token=<token>"
```

Create SES credentials to pass to MarkLogic with the `ses_user` module if the environment will have one.

Now run the MarkLogic setup jobs from GitHub. See the [delta-marklogic-deploy](https://github.com/communitiesuk/delta-marklogic-deploy) repository for details.

### 6 Public ALBs and CloudFront

CloudFront distributions with HTTPS aliases require valid SSL certificates to create successfully.
If you're creating the distributions without valid SSL certificates (for example, so that you can give DLUHC all the records in one go)
then set `domain = null` for each distribution to create without aliases.

```sh
terraform apply -target module.public_albs -target module.cloudfront_distributions
```

Create the CNAME records with another dns_records module, or by requesting them from DLUHC.
Restore the "domain" inputs once the certificate validation records are in place and apply again.

If you are managing DNS for one of the domains, then create the necessary DNS records after the CloudFront distributions are created. Do this with the dns_records module.

### 7 JasperReports server

Follow the setup instructions in the module readme.
Make sure the `jasper_s3_bucket` variable is set correctly.

```sh
terraform apply -target module.jaspersoft
```

Once the server has initialised JasperReports should be available at `https://reporting.<domain>`.

### 8 Applications

Run a full `terraform apply` to create any remaining resources.

Continue with the setup instructions in the common-payments-module and then delta repositories.

### 9 API Swagger static files

The static files in the \api\docs\src\main\resources\static folder in the delta repository should be uploaded to the relevant S3 bucket (name `dluhc-delta-api-swagger-{environment}`) in each environment to serve the swagger interface for the API. This can be done via the AWS console or CLI.
