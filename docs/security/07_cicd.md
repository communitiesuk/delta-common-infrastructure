# CI/CD

GitHub Actions is used for CI/CD.

Where workflows require AWS access, AWS users are created in the relevant account for CI/CD users.
AWS access keys are then created and stored as GitHub Actions secrets.

All repositories are stored under DLUHC's communitiesuk GitHub organisation.

## Terraform

The Terraform code is split across several repositories, but the setup for all of them is similar.

A dev account (staging and test environments) key with read only access is available for running Terraform plans for all pull requests.
A dev account admin key is stored as an environment secret and is only accessible from the main branch.
Branch protections are in place for the this repository, but not delta or common-payments-module, as they would be incompatible with the current supplier's development process.

A production account admin AWS access key is stored as an Environment secret, and requires manual approval before use.

TODO: Alarm on use of terraform admin account (MHCLG org) <https://digital.dclg.gov.uk/confluence/display/DT/Security+-+DLUHC+responsibilities>

## Application deployments

Application deployment bundles are deployed to an appropriate repository (ECR or CodeArtifact).
The same repository is shared by all environments.

A "CI" user is used to push artifacts to the repositories, and is available as a repository secret.
Artifacts used by production are immutable, so this account cannot be used to affect production services.

The per-environment terraform users are used for initiating the deployments themselves using an uploaded artefact, with the same restrictions as above.

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
| delta-common-infrastructure | Write      | Plan\*              | None                |
| delta-common-infrastructure | Maintain   | Admin               | None                |
| delta-common-infrastructure | Admin      | Admin               | Admin               |
| delta                       | Read       | None                | None                |
| delta                       | Write      | Admin               | Push artefacts\*\*  |
| delta                       | Admin      | Admin               | Admin               |
| common-payments-module      | Read       | None                | None                |
| common-payments-module      | Write      | Admin               | Push artefacts\*\*  |
| common-payments-module      | Admin      | Admin               | Admin               |
| delta-orbeon                | Read       | None                | None                |
| delta-orbeon                | Write      | None                | Push artefacts\*\*  |
| delta-orbeon                | Admin      | None                | Push artefacts\*\*  |
| delta-marklogic-deploy      | Read       | None                | None                |
| delta-marklogic-deploy      | Write      | Runner†             | Runner†             |
| delta-marklogic-deploy      | Admin      | Runner + ML secrets | Runner + ML secrets |

\* Plan - read only access to the account, including reading the terraform state and some secrets.

\*\* Being able to push artefacts to production also affects dev as they share artefact repositories. Artefacts are immutable, so this cannot be used to directly affect running production services.

† In practice, a user with access to the GitHub runner in an environment may be able to extract the MarkLogic secrets from a previous run. Repository write access should therefore be carefully controlled.

Where "Maintain" isn't specified the permissions are the same as "Write".

The named approvers for a given GitHub Actions Environment or branch protection rule will also have elevated access, though currently they are all also repository admins.
