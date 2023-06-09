This repository contains Terraform configuration for the infrastructure for data collection as a service, which consists
of Delta, the Common Payments Module, and potentially e-claims in the future.

Infrastructure specific to an individual application should live in its own codebase, but shared resources like AWS SES
or the shared VPC will be defined here.

## Repository contents

* docs - any documentation relevant to the shared infrastructure or this repository
  * adr - Architecture Decision Records
  * diagrams - architecture diagrams
* terraform - all of the Terraform code
  * modules - reusable Terraform config that can be shared between environments
  * test, staging, production - Terraform root modules for each of the three environments
  * backend - configuration for the resources that will store the remote state

## AWS access

For how we set up AWS accounts and the CLI, including Session Manager see [docs/aws_access.md](./docs/aws_access.md).

## Bastion

There's an SSH bastion server for each environment.
If you have AWS access you can create an account by uploading your SSH public key to the relevant bucket (your username will be all lowercase):

```sh
aws s3 cp ~/.ssh/id_rsa.pub s3://$(terraform output -raw bastion_ssh_keys_bucket)/<username>.pub
```

After five minutes you should be able to SSH in to the bastion server. Currently, the Softwire London and Cambridge office IPs are allowlisted.

```sh
ssh <username>@$(terraform output -raw bastion_dns_name)
```

Confirm the host key fingerprint matches the Terraform output `bastion_host_key_fingerprint`.

## CI/CD

GitHub Actions is the CI/CD platform of choice for minimal maintenance, plus it is used elsewhere in the department.

* A workflow validates all of the terraform config in all pull requests and merges to main
* There is also an "apply" workflow which can be dispatched from the Actions tab to deploy to test and staging

## tfsec

This repository uses [tfsec](https://aquasecurity.github.io/tfsec/) to scan the Terraform code for potential security issues.
It can be run using Docker

```sh
docker run --pull=always --rm -it -v "$(pwd):/src" aquasec/tfsec /src
```

It's also available via Chocolatey + other package managers, but the Docker image seems to be more up to date.

Individual rules can be ignored with a comment on the line above with the form `tfsec:ignore:<rule-name>`
e.g. `tfsec:ignore:aws-dynamodb-enable-at-rest-encryption`.

## Reserved instances

Reserved instances are a billing construct, and not configured in code like the infrastructure itself. But here is a record of the current reserved instances:

| Instance Type | Count | Used by |
|-----|:-----:|-----|
| c6a.xlarge | 3 | Production Delta website |
| r5a.8xlarge | 3 | Production ML |
| m6a.large | 1 | Production JasperSoft |
| t3a.2xlarge | 3 | Staging ML |
| t3a.large | 6 | Test ML, Test/Staging Delta website |
| t3a.medium (2 Linux, 3 Windows) | 5 | Test/Staging JasperSoft + Test/Staging/Prod AD management server |
| t3.medium (Windows) | 2 | Staging/Prod LDAP CA |

## Creating an environment

### 1 AWS Shield Advanced

Note that the Terraform code adds AWS Shield protection to some resources if configured to. (e.g. `production`).
Before protection is applied, AWS Shield Advanced needs to be manually turned on in the account. NOTE: it is
extremely expensive (as in $3000 a month, minimum 12 months), but connected accounts are covered by the same charge.
Child accounts still need the setting enabled individually, which is currently a manual process.
Do not enable unless you have a clear green light!

### 2 DNS setup

The Terraform code supports multiple domains, though one of these will have to be chosen as the primary domain
which will get passed to the applications to use for links, emails etc.

The CloudFront distributions require valid certificates before we can configure them properly.
If we control the DNS zone that's not an issue, we can just create those modules first, but if we are using records
managed by DLUHC then we will either need to stop after creating the CloudFront distributions and wait for the records
to be created, or use a secondary domain we do control in the meantime.

Add an ssl_certificates module for each set of certs you want to have available and create them,
along with an SES identity if the environment will have one.

```sh
terraform apply -target module.ssl_certs -target module.ses_identity
```

For domains we control create the DNS records to validate the certificates with a `dns_records` module and apply it now.
For other domains, request that the records from the `required_dns_records` output are created and continue.

### 3 Network + Bastion

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
Create the required containers, service users, and optionally test users, using the scripts in
`manual_scripts/active_directory`, changing and noting the passwords.

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

Set up replicas for the built in databases (Security, Meters, App-Services etc.), do NOT use Roxy's `--replicate-internals`, it will mess up the configuration.

### 6 Public ALBs and CloudFront

CloudFront distributions with HTTPS aliases require valid SSL certificates to create successfully.
If you're creating the distributions without valid SSL certificates (for example, so that you can give DLUHC all the records in one go)
then set `domain = null` for each distribution to create without aliases.

```sh
terraform apply -target module.public_albs -target module.cloudfront_distributions
```

Create the CNAME records with another dns_records module, or by requesting them from DLUHC.
Restore the "domain" inputs once the certificate validation records are in place and apply again.

If you are managing DNS for one of the domains, then create the necessary DNS records after the CloudFront distributions
are created. Do this with the dns_records module.

We use an origin timeout of 180 for the Delta website. This is above the normal limit of 60 and requires requesting a quota increase for the account from AWS support, which can be done [through the AWS console](https://console.aws.amazon.com/support/home#/case/create?issueType=service-limit-increase&limitType=service-code-cloudfront-distributions).

### 7 JasperReports server

Follow the setup instructions in the module readme.
Make sure the `jasper_s3_bucket` variable is set correctly.

```sh
terraform apply -target module.jaspersoft
```

Once the server has initialised JasperReports should be available at `https://reporting.delta.<domain>`.

### 8 Applications

Run a full `terraform apply` to create any remaining resources.

Continue with the setup instructions in the common-payments-module and then delta repositories.

### 9 API Swagger static files

The static files in the api/docs/static-site folder in the delta repository should be uploaded to the
relevant S3 bucket (name `dluhc-delta-api-swagger-{environment}`) in each environment to serve the swagger interface
for the API. This can be done via the AWS console or CLI.

### 10 AWS Shield Advanced manual config

NOTE: This is only relevant if you have enabled AWS Shield Advanced protection.
Navigate to the [AWS Shield page](https://us-east-1.console.aws.amazon.com/wafv2/shieldv2?region=us-east-1#/overview)
and confirm that resources are being protected.
You should then configure AWS SRT support if not already enabled for this account:

* Create an S3 bucket that the team can use if they need to: something along the lines of `dluhc-delta-aws-srt-support-bucket`, though it will need to be unique
* From the AWS Shield Overview page, set up SRT Access:
  * You will probably need to create a role (e.g. `AWSSRTSupport`) if one doesn't already exist.
  * Grant access to the S3 bucket you created earlier.

Then you need to manually configure Layer 7 (Application layer) protection:

* **Talk to Ben or Hugh before doing this as it can cause issues with Terraform, see DT-245**
* Navigate to the Protected resources tab
* Select the Cloudfront distribution associated with the website. (See the ACL)
* Choose Configure Protections -> Selected Resources
* Step 1 is layer 7 DDoS protection
  * the Cloudfront Distribution should already be associated with a Web ACL
  * Choose `Enable`.
* Skip past steps 2 & 3. We don't currently use these, and if we do, they should be configurable using Terraform.
* Confirm.

We don't currently use proactive engagement (from the Overview page). If we configure Route53 Healthchecks, there may
be manual steps here.
