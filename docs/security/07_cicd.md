# CI/CD

GitHub Actions is used for CI/CD.

Where workflows require AWS access, AWS users are created in the relevant account for CI/CD users.
AWS access keys are then created and stored as GitHub Actions secrets.

All repositories are stored under DLUHC's communitiesuk GitHub organisation.

## Terraform

The Terraform code is split across several repositories, but the setup for all of them is similar.

A staging/test account admin AWS access key is stored as a repository secret.

TODO: We can probably do better than this, could PRs use a key with read-only access to the state and plan with -refresh=false?
  Then the access key could at least be restricted to main and come under branch protection.

A production account admin AWS access key is stored as an Environment secret, and requires manual approval before use.

TODO: Alarm on use of terraform admin account (MHCLG org)
TODO: Confirm GitHub org does not allow write access for all members

## Application deployments

Application deployment bundles are deployed to an appropriate repository (ECR or CodeArtifact).
The same repository is shared by all environments.

A "CI" user is used to push artifacts to the repositories, and is available as a repository secret.
Artifacts used by production are immutable, so this account cannot be used to affect production services.

The per-environment terraform users are used for initiating the deployments themselves using an uploaded artefact, with the same restrictions as above.

TODO: Setup GitHub Actions Environments for Delta, CPM and Orbeon.

## MarkLogic deployments

Deployments to MarkLogic require direct network access.
For this we use an EC2 instance inside the VPC as a GitHub runner.
Access controls around GitHub runners are limited, so we attach them to a separate repository.

Deployments from this repository also use an AWS user with access to required secrets like the MarkLogic admin password.
This user is stored as environment secrets, with access control via branch protection for test/staging, and named approvers for production.

## Effective privileges

| Repository                  | Permission | Dev AWS access      | Prod AWS access     |
|-----------------------------|------------|---------------------|---------------------|
| communitiesuk organisation  | Admin      | Admin               | Admin               |
| delta-common-infrastructure | Read       | None                | None                |
| delta-common-infrastructure | Write      | Admin               | None                |
| delta-common-infrastructure | Admin      | Admin               | Admin               |
| delta                       | Read       | None                | None                |
| delta                       | Write      | Admin               | Push artefacts      |
| delta                       | Admin      | Admin               | Admin               |
| common-payments-module      | Read       | None                | None                |
| common-payments-module      | Write      | Admin               | Push artefacts      |
| common-payments-module      | Admin      | Admin               | Admin               |
| delta-orbeon                | Read       | None                | None                |
| delta-orbeon                | Write      | None                | Push artefacts      |
| delta-orbeon                | Admin      | None                | Push artefacts      |
| delta-marklogic-deploy      | Read       | None                | None                |
| delta-marklogic-deploy      | Write      | Runner              | Runner              |
| delta-marklogic-deploy      | push main  | Runner + ML secrets | Runner              |
| delta-marklogic-deploy      | Admin      | Runner + ML secrets | Runner + ML secrets |

The "Maintainer" role is not currently used.

The named approvers for a given GitHub Actions Environment or branch protection rule will also have elevated access if they are not already a repository admin.

Being able to push artefacts to production also affects dev as they share a repository.
